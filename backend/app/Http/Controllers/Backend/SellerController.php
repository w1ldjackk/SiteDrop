<?php

namespace App\Http\Controllers\Backend;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\Role;
use App\Models\SellerProfile;
use App\Models\User;
use App\Services\Activity\ActivityActions;
use App\Services\Activity\ActivityLogger;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use Inertia\Inertia;
use Inertia\Response;

class SellerController extends Controller
{
    /**
     * List sellers (SellerProfile + User owner).
     */
    public function index(Request $request): Response
    {
        // One row per profile; never list soft-deleted duplicates
        $query = SellerProfile::query()
            ->with(['user:id,name,email,phone'])
            ->withCount(['orders', 'products'])
            ->whereHas('user') // drop orphan profiles
            ->latest();

        if ($status = $request->input('status')) {
            $query->where('status', $status);
        }

        if ($search = $request->input('search')) {
            $query->where(function ($q) use ($search) {
                $q->where('business_name', 'like', "%{$search}%")
                    ->orWhere('business_email', 'like', "%{$search}%")
                    ->orWhere('business_phone', 'like', "%{$search}%")
                    ->orWhereHas('user', function ($uq) use ($search) {
                        $uq->where('name', 'like', "%{$search}%")
                            ->orWhere('email', 'like', "%{$search}%")
                            ->orWhere('phone', 'like', "%{$search}%");
                    });
            });
        }

        $sellers = $query->paginate((int) $request->input('per_page', 15))
            ->withQueryString()
            ->through(fn (SellerProfile $s) => $this->transformList($s));

        $user = $request->user();

        return Inertia::render('backend/Sellers/index', [
            'sellers' => $sellers,
            'filters' => $request->only(['search', 'status']),
            'statuses' => $this->statuses(),
            'business_types' => $this->businessTypes(),
            'can' => [
                'create' => $this->can($user, 'create sellers', 'manage sellers'),
                'update' => $this->can($user, 'edit sellers', 'manage sellers'),
                'delete' => $this->can($user, 'delete sellers', 'manage sellers'),
            ],
        ]);
    }

    public function create(Request $request): Response
    {
        abort_unless(
            $this->can($request->user(), 'create sellers', 'manage sellers'),
            403
        );

        return Inertia::render('backend/Sellers/create', [
            'statuses' => $this->statuses(),
            'business_types' => $this->businessTypes(),
            // Existing users without a seller profile (optional link)
            'users' => User::query()
                ->whereDoesntHave('sellerProfile')
                ->orderBy('name')
                ->limit(100)
                ->get(['id', 'name', 'email', 'phone'])
                ->map(fn (User $u) => [
                    'id' => $u->id,
                    'name' => $u->name,
                    'email' => $u->email,
                    'phone' => $u->phone,
                    'label' => trim($u->name.' · '.($u->email ?: $u->phone ?: '#'.$u->id)),
                ]),
        ]);
    }

    /**
     * Create User (optional new) + SellerProfile and assign seller role.
     */
    public function store(Request $request): RedirectResponse
    {
        abort_unless(
            $this->can($request->user(), 'create sellers', 'manage sellers'),
            403
        );

        $data = $request->validate($this->storeRules());

        $seller = DB::transaction(function () use ($data) {
            if (! empty($data['user_id'])) {
                $user = User::findOrFail($data['user_id']);
                if (SellerProfile::where('user_id', $user->id)->exists()) {
                    abort(422, 'This user already has a seller profile.');
                }
            } else {
                $user = User::create([
                    'name' => $data['owner_name'],
                    'email' => $data['owner_email'] ?? null,
                    'phone' => $data['owner_phone'] ?? null,
                    'password' => Hash::make($data['password'] ?? 'password123'),
                    'role' => 'seller',
                    'email_verified_at' => now(),
                ]);
            }

            Role::findOrCreate('seller', 'web');
            $roles = $user->getRoleNames()->all();
            if (! in_array('seller', $roles, true)) {
                $roles[] = 'seller';
            }
            $user->syncRoles(array_values(array_filter(
                $roles,
                static fn ($r) => $r !== 'super-admin'
            )));
            if ($user->role !== 'super-admin') {
                $user->forceFill(['role' => 'seller'])->saveQuietly();
            }

            $profile = SellerProfile::create([
                'user_id' => $user->id,
                'business_name' => $data['business_name'],
                'business_type' => $data['business_type'] ?? SellerProfile::BUSINESS_TYPE_SUPPLIER,
                'business_registration_number' => $data['business_registration_number'] ?? null,
                'tax_id' => $data['tax_id'] ?? null,
                'business_phone' => $data['business_phone'] ?? $user->phone,
                'business_email' => $data['business_email'] ?? $user->email,
                'website' => $data['website'] ?? null,
                'description' => $data['description'] ?? null,
                'status' => $data['status'] ?? SellerProfile::STATUS_PENDING,
                'commission_rate' => $data['commission_rate'] ?? 10,
                'minimum_order_amount' => $data['minimum_order_amount'] ?? 0,
                'delivery_radius_km' => $data['delivery_radius_km'] ?? null,
                'bank_account_name' => $data['bank_account_name'] ?? null,
                'bank_account_number' => $data['bank_account_number'] ?? null,
                'bank_name' => $data['bank_name'] ?? null,
                'bank_branch' => $data['bank_branch'] ?? null,
                'approved_at' => ($data['status'] ?? null) === SellerProfile::STATUS_APPROVED
                    ? now()
                    : null,
            ]);

            return $profile;
        });

        ActivityLogger::log(
            ActivityActions::SELLER_ONBOARDED,
            "Admin created seller \"{$seller->business_name}\"",
            $seller,
            ['seller_id' => $seller->id, 'user_id' => $seller->user_id],
            module: 'sellers',
            userId: Auth::id(),
        );

        return redirect()
            ->to("/admin/sellers/{$seller->id}")
            ->with('success', 'Seller created successfully.');
    }

    public function show(int $id): Response
    {
        $seller = SellerProfile::with(['user:id,name,email,phone,role'])
            ->withCount(['orders', 'products', 'reviews'])
            ->findOrFail($id);

        $stats = [
            'orders_total' => Order::where('seller_id', $seller->user_id)->count(),
            'orders_pending' => Order::where('seller_id', $seller->user_id)
                ->where('status', Order::STATUS_PENDING)
                ->count(),
            'orders_completed' => Order::where('seller_id', $seller->user_id)
                ->where('status', Order::STATUS_COMPLETED)
                ->count(),
            'revenue' => (float) Order::where('seller_id', $seller->user_id)
                ->where('status', Order::STATUS_COMPLETED)
                ->sum('seller_earnings'),
        ];

        $user = Auth::user();

        return Inertia::render('backend/Sellers/show', [
            'seller' => $this->transformDetail($seller),
            'stats' => $stats,
            'can' => [
                'update' => $this->can($user, 'edit sellers', 'manage sellers'),
                'delete' => $this->can($user, 'delete sellers', 'manage sellers'),
                'moderate' => $this->can(
                    $user,
                    'approve sellers',
                    'reject sellers',
                    'suspend sellers',
                    'activate sellers',
                    'manage sellers'
                ),
                'view_documents' => $this->can(
                    $user,
                    'view seller documents',
                    'manage sellers',
                    'approve sellers'
                ),
            ],
        ]);
    }

    public function edit(Request $request, int $id): Response
    {
        abort_unless(
            $this->can($request->user(), 'edit sellers', 'manage sellers'),
            403
        );

        $seller = SellerProfile::with(['user:id,name,email,phone'])->findOrFail($id);

        return Inertia::render('backend/Sellers/edit', [
            'seller' => $this->transformDetail($seller),
            'statuses' => $this->statuses(),
            'business_types' => $this->businessTypes(),
        ]);
    }

    public function update(Request $request, int $id): RedirectResponse
    {
        abort_unless(
            $this->can($request->user(), 'edit sellers', 'manage sellers'),
            403
        );

        $seller = SellerProfile::with('user')->findOrFail($id);
        $data = $request->validate($this->updateRules($seller));

        DB::transaction(function () use ($seller, $data) {
            $seller->update([
                'business_name' => $data['business_name'],
                'business_type' => $data['business_type'] ?? $seller->business_type,
                'business_registration_number' => $data['business_registration_number'] ?? null,
                'tax_id' => $data['tax_id'] ?? null,
                'business_phone' => $data['business_phone'] ?? null,
                'business_email' => $data['business_email'] ?? null,
                'website' => $data['website'] ?? null,
                'description' => $data['description'] ?? null,
                'status' => $data['status'] ?? $seller->status,
                'commission_rate' => $data['commission_rate'] ?? $seller->commission_rate,
                'minimum_order_amount' => $data['minimum_order_amount'] ?? $seller->minimum_order_amount,
                'delivery_radius_km' => $data['delivery_radius_km'] ?? $seller->delivery_radius_km,
                'bank_account_name' => $data['bank_account_name'] ?? null,
                'bank_account_number' => $data['bank_account_number'] ?? null,
                'bank_name' => $data['bank_name'] ?? null,
                'bank_branch' => $data['bank_branch'] ?? null,
                'rejected_reason' => $data['rejected_reason'] ?? $seller->rejected_reason,
            ]);

            if (($data['status'] ?? null) === SellerProfile::STATUS_APPROVED && ! $seller->approved_at) {
                $seller->forceFill(['approved_at' => now()])->saveQuietly();
            }

            if ($seller->user) {
                $userUpdates = array_filter([
                    'name' => $data['owner_name'] ?? null,
                    'email' => array_key_exists('owner_email', $data) ? $data['owner_email'] : null,
                    'phone' => array_key_exists('owner_phone', $data) ? $data['owner_phone'] : null,
                ], static fn ($v) => $v !== null && $v !== '');

                if ($userUpdates !== []) {
                    $seller->user->fill($userUpdates)->save();
                }

                if (! empty($data['password'])) {
                    $seller->user->forceFill([
                        'password' => Hash::make($data['password']),
                    ])->save();
                }
            }
        });

        ActivityLogger::log(
            'seller.updated',
            "Admin updated seller \"{$seller->business_name}\"",
            $seller,
            module: 'sellers',
            userId: Auth::id(),
        );

        return redirect()
            ->to("/admin/sellers/{$seller->id}")
            ->with('success', 'Seller updated successfully.');
    }

    public function destroy(Request $request, int $id): RedirectResponse
    {
        abort_unless(
            $this->can($request->user(), 'delete sellers', 'manage sellers'),
            403
        );

        $seller = SellerProfile::with('user')->findOrFail($id);
        $name = $seller->business_name;
        $userId = $seller->user_id;

        $seller->delete(); // soft delete

        // Drop seller role if they have no other profile
        if ($user = User::find($userId)) {
            if (! $user->sellerProfile()->exists()) {
                $roles = array_values(array_filter(
                    $user->getRoleNames()->all(),
                    static fn ($r) => $r !== 'seller'
                ));
                if ($roles === []) {
                    $roles = ['buyer'];
                }
                $user->syncRoles($roles);
                if ($user->role === 'seller') {
                    $user->forceFill(['role' => $roles[0]])->saveQuietly();
                }
            }
        }

        ActivityLogger::log(
            'seller.deleted',
            "Admin deleted seller \"{$name}\"",
            null,
            ['seller_id' => $id, 'user_id' => $userId, 'name' => $name],
            level: \App\Models\ActivityLog::LEVEL_WARNING,
            module: 'sellers',
            userId: Auth::id(),
        );

        return redirect()
            ->to('/admin/sellers')
            ->with('success', 'Seller deleted.');
    }

    public function approve(Request $request, int $id): RedirectResponse
    {
        abort_unless(
            $this->can($request->user(), 'approve sellers', 'manage sellers'),
            403
        );

        $seller = SellerProfile::findOrFail($id);
        $seller->update([
            'status' => SellerProfile::STATUS_APPROVED,
            'approved_at' => now(),
            'rejected_reason' => null,
        ]);

        ActivityLogger::log(
            ActivityActions::SELLER_APPROVED,
            "Seller {$seller->business_name} approved",
            $seller,
            module: 'sellers',
            userId: Auth::id(),
        );

        return back()->with('success', 'Seller approved.');
    }

    public function reject(Request $request, int $id): RedirectResponse
    {
        abort_unless(
            $this->can($request->user(), 'reject sellers', 'manage sellers'),
            403
        );

        $seller = SellerProfile::findOrFail($id);
        $seller->update([
            'status' => SellerProfile::STATUS_REJECTED,
            'rejected_reason' => $request->input('reason', 'Rejected by admin'),
        ]);

        ActivityLogger::log(
            ActivityActions::SELLER_REJECTED,
            "Seller {$seller->business_name} rejected",
            $seller,
            ['reason' => $seller->rejected_reason],
            module: 'sellers',
            userId: Auth::id(),
        );

        return back()->with('success', 'Seller rejected.');
    }

    public function suspend(Request $request, int $id): RedirectResponse
    {
        abort_unless(
            $this->can($request->user(), 'suspend sellers', 'manage sellers'),
            403
        );

        $seller = SellerProfile::findOrFail($id);
        $seller->update(['status' => SellerProfile::STATUS_SUSPENDED]);

        ActivityLogger::log(
            ActivityActions::SELLER_SUSPENDED,
            "Seller {$seller->business_name} suspended",
            $seller,
            module: 'sellers',
            userId: Auth::id(),
        );

        return back()->with('success', 'Seller suspended.');
    }

    public function activate(Request $request, int $id): RedirectResponse
    {
        abort_unless(
            $this->can($request->user(), 'activate sellers', 'manage sellers'),
            403
        );

        $seller = SellerProfile::findOrFail($id);
        $seller->update([
            'status' => SellerProfile::STATUS_APPROVED,
            'approved_at' => $seller->approved_at ?? now(),
            'rejected_reason' => null,
        ]);

        ActivityLogger::log(
            ActivityActions::SELLER_ACTIVATED,
            "Seller {$seller->business_name} activated",
            $seller,
            module: 'sellers',
            userId: Auth::id(),
        );

        return back()->with('success', 'Seller activated.');
    }

    public function performance(int $id): Response
    {
        return $this->show($id);
    }

    // ───────────────────────── helpers ─────────────────────────

    /**
     * Super-admin always allowed; otherwise any of the given permissions.
     */
    private function can($user, string ...$permissions): bool
    {
        if (! $user) {
            return false;
        }

        // Super-admin can do anything
        if ($user->isSuperAdmin()) {
            return true;
        }

        // Platform admin role still full seller management
        if ($user->isAdmin() || $user->hasRole('admin') || $user->role === 'admin') {
            return true;
        }

        foreach ($permissions as $permission) {
            try {
                if ($user->hasPermissionTo($permission, 'web')
                    || $user->hasPermissionTo($permission)
                ) {
                    return true;
                }
            } catch (\Throwable) {
                // permission not registered
            }
        }

        return false;
    }

    /** @deprecated use can() */
    private function canManage($user): bool
    {
        return $this->can($user, 'manage sellers', 'approve sellers', 'edit sellers');
    }

    /** @return list<string> */
    private function statuses(): array
    {
        return [
            SellerProfile::STATUS_PENDING,
            SellerProfile::STATUS_APPROVED,
            SellerProfile::STATUS_SUSPENDED,
            SellerProfile::STATUS_REJECTED,
        ];
    }

    /** @return list<string> */
    private function businessTypes(): array
    {
        return [
            SellerProfile::BUSINESS_TYPE_QUARRY,
            SellerProfile::BUSINESS_TYPE_TRUCK_OWNER,
            SellerProfile::BUSINESS_TYPE_SUPPLIER,
            SellerProfile::BUSINESS_TYPE_DISTRIBUTOR,
        ];
    }

    private function storeRules(): array
    {
        return [
            'user_id' => [
                'nullable',
                'integer',
                'exists:users,id',
                Rule::unique('seller_profiles', 'user_id'),
            ],
            'owner_name' => ['required_without:user_id', 'nullable', 'string', 'max:255'],
            'owner_email' => ['nullable', 'email', 'max:255', 'unique:users,email'],
            'owner_phone' => ['nullable', 'string', 'max:30'],
            'password' => ['nullable', 'string', 'min:6'],
            'business_name' => ['required', 'string', 'max:255'],
            'business_type' => ['nullable', 'string', 'max:50'],
            'business_registration_number' => ['nullable', 'string', 'max:100'],
            'tax_id' => ['nullable', 'string', 'max:100'],
            'business_phone' => ['nullable', 'string', 'max:30'],
            'business_email' => ['nullable', 'email', 'max:255'],
            'website' => ['nullable', 'string', 'max:255'],
            'description' => ['nullable', 'string', 'max:2000'],
            'status' => ['nullable', Rule::in($this->statuses())],
            'commission_rate' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'minimum_order_amount' => ['nullable', 'numeric', 'min:0'],
            'delivery_radius_km' => ['nullable', 'numeric', 'min:0'],
            'bank_account_name' => ['nullable', 'string', 'max:255'],
            'bank_account_number' => ['nullable', 'string', 'max:100'],
            'bank_name' => ['nullable', 'string', 'max:255'],
            'bank_branch' => ['nullable', 'string', 'max:255'],
        ];
    }

    private function updateRules(SellerProfile $seller): array
    {
        $userId = $seller->user_id;

        return [
            'owner_name' => ['nullable', 'string', 'max:255'],
            'owner_email' => [
                'nullable',
                'email',
                'max:255',
                Rule::unique('users', 'email')->ignore($userId),
            ],
            'owner_phone' => ['nullable', 'string', 'max:30'],
            'password' => ['nullable', 'string', 'min:6'],
            'business_name' => ['required', 'string', 'max:255'],
            'business_type' => ['nullable', 'string', 'max:50'],
            'business_registration_number' => ['nullable', 'string', 'max:100'],
            'tax_id' => ['nullable', 'string', 'max:100'],
            'business_phone' => ['nullable', 'string', 'max:30'],
            'business_email' => ['nullable', 'email', 'max:255'],
            'website' => ['nullable', 'string', 'max:255'],
            'description' => ['nullable', 'string', 'max:2000'],
            'status' => ['nullable', Rule::in($this->statuses())],
            'commission_rate' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'minimum_order_amount' => ['nullable', 'numeric', 'min:0'],
            'delivery_radius_km' => ['nullable', 'numeric', 'min:0'],
            'bank_account_name' => ['nullable', 'string', 'max:255'],
            'bank_account_number' => ['nullable', 'string', 'max:100'],
            'bank_name' => ['nullable', 'string', 'max:255'],
            'bank_branch' => ['nullable', 'string', 'max:255'],
            'rejected_reason' => ['nullable', 'string', 'max:500'],
        ];
    }

    private function transformList(SellerProfile $s): array
    {
        return [
            'id' => $s->id,
            'seller_code' => $s->public_id,
            'business_name' => $s->business_name,
            'business_type' => $s->business_type,
            'business_phone' => $s->business_phone,
            'business_email' => $s->business_email,
            'status' => $s->status,
            'orders_count' => $s->orders_count ?? 0,
            'products_count' => $s->products_count ?? 0,
            'docs_count' => is_array($s->verification_documents)
                ? count($s->verification_documents)
                : 0,
            'user' => $s->user ? [
                'id' => $s->user->id,
                'name' => $s->user->name,
                'email' => $s->user->email,
                'phone' => $s->user->phone,
            ] : null,
            'created_at' => optional($s->created_at)?->toDateTimeString(),
        ];
    }

    /**
     * Full profile payload for admin/super-admin (all fields, including docs before approval).
     */
    private function transformDetail(SellerProfile $seller): array
    {
        $docs = $this->normalizeDocuments($seller->verification_documents);

        return [
            'id' => $seller->id,
            'seller_code' => $seller->public_id,
            'user_id' => $seller->user_id,
            'business_name' => $seller->business_name,
            'business_type' => $seller->business_type,
            'business_registration_number' => $seller->business_registration_number,
            'tax_id' => $seller->tax_id,
            'business_phone' => $seller->business_phone,
            'business_email' => $seller->business_email,
            'website' => $seller->website,
            'description' => $seller->description,
            'logo_url' => $seller->logo_url,
            'cover_image_url' => $seller->cover_image_url,
            'status' => $seller->status,
            'email_verified' => (bool) $seller->email_verified,
            'service_areas' => $seller->service_areas ?? [],
            'commission_rate' => $seller->commission_rate,
            'minimum_order_amount' => $seller->minimum_order_amount,
            'delivery_radius_km' => $seller->delivery_radius_km,
            'bank_account_name' => $seller->bank_account_name,
            'bank_account_number' => $seller->bank_account_number,
            'bank_name' => $seller->bank_name,
            'bank_branch' => $seller->bank_branch,
            'verification_documents' => $docs,
            'social_links' => $seller->social_links ?? [],
            'business_hours' => $seller->business_hours ?? [],
            'orders_count' => $seller->orders_count ?? 0,
            'products_count' => $seller->products_count ?? 0,
            'reviews_count' => $seller->reviews_count ?? 0,
            'approved_at' => optional($seller->approved_at)?->toDateTimeString(),
            'rejected_reason' => $seller->rejected_reason,
            'user' => $seller->user ? [
                'id' => $seller->user->id,
                'name' => $seller->user->name,
                'email' => $seller->user->email,
                'phone' => $seller->user->phone,
                'role' => $seller->user->role ?? null,
                'phone_verified' => (bool) ($seller->user->phone_verified ?? false),
            ] : null,
            'created_at' => optional($seller->created_at)?->toDateTimeString(),
            'updated_at' => optional($seller->updated_at)?->toDateTimeString(),
        ];
    }

    /**
     * Normalize verification_documents JSON into a list of {name,url,type,size?}.
     *
     * @param  mixed  $docs
     * @return list<array{name: string, url: ?string, type: ?string, size: mixed}>
     */
    private function normalizeDocuments(mixed $docs): array
    {
        if (! is_array($docs) || $docs === []) {
            return [];
        }

        $out = [];
        foreach ($docs as $key => $doc) {
            if (is_string($doc)) {
                $out[] = [
                    'name' => is_string($key) ? $key : basename(parse_url($doc, PHP_URL_PATH) ?: $doc),
                    'url' => $doc,
                    'type' => null,
                    'size' => null,
                ];
                continue;
            }
            if (! is_array($doc)) {
                continue;
            }
            $out[] = [
                'name' => (string) ($doc['name'] ?? $doc['title'] ?? $doc['label'] ?? (is_string($key) ? $key : 'Document')),
                'url' => $doc['url'] ?? $doc['path'] ?? $doc['file'] ?? $doc['src'] ?? null,
                'type' => $doc['type'] ?? $doc['mime'] ?? $doc['document_type'] ?? null,
                'size' => $doc['size'] ?? null,
            ];
        }

        return $out;
    }
}
