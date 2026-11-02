<?php

namespace App\Http\Controllers\Backend;

use App\Http\Controllers\Controller;
use App\Jobs\Notification\SendPushNotification;
use App\Models\Notification;
use App\Models\Truck;
use App\Models\TruckLog;
use App\Models\User;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

class TruckController extends Controller
{
    /**
     * Trucks & Drivers combined admin page.
     */
    public function index(Request $request): Response
    {
        $tab = $request->input('tab', 'trucks');

        $truckQuery = Truck::query()
            ->with([
                'user:id,name,phone',
                'driver:id,name,phone',
            ])
            ->latest();

        if ($search = $request->input('search')) {
            $truckQuery->where(function ($q) use ($search) {
                $q->where('registration_number', 'like', "%{$search}%")
                    ->orWhere('make', 'like', "%{$search}%")
                    ->orWhere('model', 'like', "%{$search}%")
                    ->orWhere('company_name', 'like', "%{$search}%");
            });
        }

        if ($status = $request->input('status')) {
            $truckQuery->where('status', $status);
        }

        $trucks = $truckQuery->paginate((int) $request->input('per_page', 15), ['*'], 'trucks_page')
            ->withQueryString()
            ->through(fn (Truck $t) => [
                'id' => $t->id,
                'registration_number' => $t->registration_number,
                'make' => $t->make,
                'model' => $t->model,
                'year' => $t->year,
                'vehicle_type' => $t->vehicle_type,
                'capacity_tons' => $t->capacity_tons,
                'status' => $t->status,
                'is_verified' => (bool) $t->is_verified,
                'owner' => $t->user,
                'driver' => $t->driver,
                'created_at' => optional($t->created_at)?->toDateTimeString(),
            ]);

        $driverQuery = User::query()
            ->where(function ($q) {
                $q->where('role', 'driver')
                    ->orWhereHas('roles', fn ($r) => $r->where('name', 'driver'));
            })
            ->latest();

        if ($search = $request->input('search')) {
            $driverQuery->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%")
                    ->orWhere('phone', 'like', "%{$search}%");
            });
        }

        $drivers = $driverQuery->paginate((int) $request->input('per_page', 15), ['*'], 'drivers_page')
            ->withQueryString()
            ->through(fn (User $u) => [
                'id' => $u->id,
                'name' => $u->name,
                'email' => $u->email,
                'phone' => $u->phone,
                'status' => $u->status ?? 'active',
                'created_at' => optional($u->created_at)?->toDateTimeString(),
            ]);

        return Inertia::render('backend/Trucks/index', [
            'trucks' => $trucks,
            'drivers' => $drivers,
            'tab' => $tab,
            'filters' => $request->only(['search', 'status', 'tab']),
        ]);
    }

    public function show(int $id): Response
    {
        $truck = Truck::with([
            'user:id,name,phone',
            'driver:id,name,phone',
            'documents',
            'insurance',
            'maintenanceRecords' => fn ($q) => $q->orderByDesc('performed_at')->limit(10),
            'logs' => fn ($q) => $q->orderByDesc('created_at')->limit(20),
        ])->findOrFail($id);

        return Inertia::render('backend/Trucks/show', [
            'truck' => $truck,
        ]);
    }

    /**
     * Approve a truck for matching.
     */
    public function approve(Request $request, int $id)
    {
        $truck = Truck::findOrFail($id);
        $data = $request->validate([
            'comment' => ['nullable', 'string', 'max:2000'],
        ]);

        $truck->update([
            'is_verified' => true,
            'rejected_reason' => null,
            'verified_at' => now(),
        ]);
        TruckLog::log(
            $truck->id,
            TruckLog::ACTION_UPDATED,
            'Truck approved by admin'.(
                ! empty($data['comment'] ?? '') ? ": {$data['comment']}" : ''
            )
        );

        $this->notifyDriver(
            $truck,
            'Truck approved',
            "Your truck {$truck->registration_number} is verified and match-ready."
        );

        return back()->with(
            'success',
            "Truck {$truck->registration_number} approved."
        );
    }

    /**
     * Reject a truck with a comment.
     */
    public function reject(Request $request, int $id)
    {
        $data = $request->validate([
            'reason' => ['required', 'string', 'max:2000'],
        ]);

        $truck = Truck::findOrFail($id);
        $truck->update([
            'is_verified' => false,
            'rejected_reason' => $data['reason'],
            'verified_at' => null,
        ]);
        TruckLog::log($truck->id, TruckLog::ACTION_UPDATED, 'Truck rejected by admin');

        $this->notifyDriver(
            $truck,
            'Truck needs attention',
            "Your truck {$truck->registration_number} was not approved: {$data['reason']}"
        );

        return back()->with('success', "Truck {$truck->registration_number} rejected.");
    }

    private function notifyDriver(Truck $truck, string $title, string $body): void
    {
        $driverId = $truck->driver_id ?? $truck->user_id;
        if (! $driverId) {
            return;
        }

        Notification::createNotification(
            $driverId,
            $title,
            $body,
            'system',
            ['truck_id' => $truck->id],
            'in_app',
            'high'
        );

        $driver = User::find($driverId);
        if ($driver?->fcm_token) {
            dispatch(new SendPushNotification(
                $driver->fcm_token,
                $title,
                $body,
                ['truck_id' => $truck->id, 'type' => 'truck_verification']
            ));
        }
    }
}
