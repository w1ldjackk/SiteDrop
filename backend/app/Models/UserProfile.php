<?php
// app/Models/UserProfile.php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class UserProfile extends Model
{
    use HasFactory, SoftDeletes;

    protected $table = 'profiles'; // Keep the same table name

    protected $fillable = [
        'user_id',
        'first_name',
        'last_name',
        'date_of_birth',
        'gender',
        'alternate_phone',
        'address',
        'coordinates',
        'avatar_url',
        'bio',
        'social_links',
        'preferences',
        'identity_verified_at',
        'identity_document',
        'nationality',
        'occupation',
        'company',
        'emergency_contact_name',
        'emergency_contact_phone',
        'emergency_contact_relationship',
    ];

    protected $casts = [
        'coordinates' => 'array',
        'social_links' => 'array',
        'preferences' => 'array',
        'date_of_birth' => 'date',
        'identity_verified_at' => 'datetime',
    ];

    // Relationships
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    // Accessors
    public function getFullNameAttribute()
    {
        if ($this->first_name && $this->last_name) {
            return $this->first_name . ' ' . $this->last_name;
        }
        return $this->user->name ?? null;
    }

    public function getAgeAttribute()
    {
        if ($this->date_of_birth) {
            return $this->date_of_birth->age;
        }
        return null;
    }

    public function getAvatarAttribute()
    {
        if ($this->avatar_url) {
            return $this->avatar_url;
        }
        $name = $this->full_name ?? $this->user->name ?? 'User';
        return 'https://ui-avatars.com/api/?name=' . urlencode($name) . '&background=random';
    }

    public function getIsIdentityVerifiedAttribute()
    {
        return !is_null($this->identity_verified_at);
    }

    public function getFullAddressAttribute()
    {
        return $this->address;
    }

    public function getLocationAttribute()
    {
        if ($this->coordinates) {
            return [
                'lat' => $this->coordinates['lat'] ?? null,
                'lng' => $this->coordinates['lng'] ?? null,
            ];
        }
        return null;
    }

    // Methods
    public function markIdentityAsVerified()
    {
        $this->update(['identity_verified_at' => now()]);
    }

    public function updatePreferences(array $preferences)
    {
        $this->update([
            'preferences' => array_merge($this->preferences ?? [], $preferences),
        ]);
    }

    public function updateSocialLinks(array $links)
    {
        $this->update([
            'social_links' => array_merge($this->social_links ?? [], $links),
        ]);
    }

    public function isComplete(): bool
    {
        return !empty($this->first_name) &&
            !empty($this->last_name) &&
            !empty($this->address) &&
            !is_null($this->date_of_birth);
    }
}
