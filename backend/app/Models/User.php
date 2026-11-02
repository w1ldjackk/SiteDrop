<?php

namespace App\Models;

use App\Models\Address;
use App\Models\Delivery;
use App\Models\Notification;
use App\Models\Order;
use App\Models\Product;
use App\Models\Review;
use App\Models\SellerProfile;
use App\Models\Site;
use App\Models\Truck;
use App\Models\UserProfile;
use App\Models\Wallet;
use App\Models\Wishlist;
use App\Traits\HasAppRoles;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Fortify\TwoFactorAuthenticatable;
use Laravel\Sanctum\HasApiTokens;
use Spatie\Permission\Traits\HasRoles;

class User extends Authenticatable
{
    use HasApiTokens,
        HasAppRoles,
        HasFactory,
        Notifiable,
        HasRoles,
        SoftDeletes,
        TwoFactorAuthenticatable;

    /**
     * The attributes that are mass assignable.
     */
    protected $fillable = [
        'name',
        'email',
        'password',
        'phone',
        'phone_country',
        'phone_verified',
        'role',
        'current_site_id',
        'referral_code',
        'last_active_at',
        'preferences',
        'fcm_token',
        'device_type', // ios, android, web
        'is_online', // driver presence for SiteDrop-style dispatch
        'last_location', // {lat, lng, timestamp}
    ];

    /**
     * The attributes that should be hidden for serialization.
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Get the attributes that should be cast.
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'phone_verified' => 'boolean',
            'last_active_at' => 'datetime',
            'preferences' => 'array',
            'is_online' => 'boolean',
            'last_location' => 'array',
        ];
    }

    // ====================== Relationships ======================

    public function profile()
    {
        return $this->hasOne(UserProfile::class);
    }

    public function sites()
    {
        return $this->hasMany(Site::class);
    }

    public function currentSite()
    {
        return $this->belongsTo(Site::class, 'current_site_id');
    }

    public function trucks()
    {
        return $this->hasMany(Truck::class);
    }

    public function wallet()
    {
        return $this->hasOne(Wallet::class);
    }

    public function addresses()
    {
        return $this->hasMany(Address::class);
    }

    public function defaultAddress()
    {
        return $this->hasOne(Address::class)->where('is_default', true);
    }

    // Seller specific relationships
    public function sellerProfile()
    {
        return $this->hasOne(SellerProfile::class);
    }

    public function products()
    {
        return $this->hasMany(Product::class, 'seller_id');
    }

    public function sellerOrders()
    {
        return $this->hasMany(Order::class, 'seller_id');
    }

    // Buyer specific relationships
    public function buyerOrders()
    {
        return $this->hasMany(Order::class, 'buyer_id');
    }

    public function wishlists()
    {
        return $this->hasMany(Wishlist::class);
    }

    public function wishlistProducts()
    {
        return $this->belongsToMany(Product::class, 'wishlists')
            ->withTimestamps();
    }

    // Reviews
    public function reviewsGiven()
    {
        return $this->hasMany(Review::class, 'reviewer_id');
    }

    public function reviewsReceived()
    {
        return $this->hasMany(Review::class, 'reviewee_id');
    }

    // Deliveries (as driver)
    public function deliveries()
    {
        return $this->hasMany(Delivery::class, 'driver_id');
    }

    // Notifications
    public function notifications()
    {
        return $this->hasMany(Notification::class);
    }

    public function unreadNotifications()
    {
        return $this->notifications()->where('read_at', null);
    }

    // Role helpers: App\Traits\HasAppRoles

    // ====================== Phone Verification ======================

    public function hasVerifiedPhone(): bool
    {
        return $this->phone_verified === true;
    }

    public function markPhoneAsVerified(): void
    {
        $this->forceFill(['phone_verified' => true])->save();
    }

    // ====================== Auto Email for OTP Users ======================

    protected static function boot()
    {
        parent::boot();

        static::creating(function ($user) {
            // Only auto-generate email for OTP-created users (no email in request)
            if (empty($user->email) && !empty($user->phone)) {
                $user->email = strtolower(str_replace([' ', '-', '+'], '', $user->phone)) . '@sitedrop.gh';
            }

            // Generate unique referral code
            if (empty($user->referral_code)) {
                $user->referral_code = self::generateReferralCode();
            }
        });

        static::created(function ($user) {
            // Create wallet for new user
            if (!$user->wallet) {
                $user->wallet()->create([
                    'balance' => 0,
                    'currency' => 'GHS',
                ]);
            }
        });
    }

    private static function generateReferralCode(): string
    {
        $prefix = 'SD';
        $random = strtoupper(substr(md5(uniqid()), 0, 6));
        return $prefix . $random;
    }

    // ====================== Spatie Permission Methods ======================

    /**
     * Default Spatie guard for this model.
     *
     * Admin roles/permissions are seeded with guard_name=web. Returning "sanctum"
     * here caused GuardDoesNotMatch / RoleDoesNotExist when assigning web roles.
     * API auth still uses Sanctum tokens; Spatie checks use the web guard.
     */
    public function getDefaultGuardName(): string
    {
        return 'web';
    }

    public function getProfile()
    {
        if (!$this->relationLoaded('profile')) {
            $this->load('profile');
        }

        if (!$this->profile) {
            $this->profile = $this->profile()->create([
                'first_name' => $this->name ?? null,
                'last_name' => null,
            ]);
        }

        return $this->profile;
    }
}
