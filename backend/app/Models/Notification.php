<?php
// app/Models/Notification.php

namespace App\Models;

use App\Enums\NotificationChannel;
use App\Enums\NotificationDeliveryStatus;
use App\Enums\NotificationPriority;
use App\Enums\NotificationType;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Notification extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'type',
        'title',
        'body',
        'data',
        'action_url',
        'image_url',
        'read_at',
        'sent_at',
        'delivery_status',
        'channel',
        'priority',
        'expires_at',
    ];

    protected $casts = [
        'data' => 'array',
        'read_at' => 'datetime',
        'sent_at' => 'datetime',
        'expires_at' => 'datetime',
        'type' => NotificationType::class,
        'channel' => NotificationChannel::class,
        'priority' => NotificationPriority::class,
        'delivery_status' => NotificationDeliveryStatus::class,
    ];

    // Backward-compatible constants (prefer App\Enums\*)
    const TYPE_ORDER = NotificationType::Order->value;
    const TYPE_PAYMENT = NotificationType::Payment->value;
    const TYPE_DELIVERY = NotificationType::Delivery->value;
    const TYPE_SYSTEM = NotificationType::System->value;
    const TYPE_PROMOTION = NotificationType::Promotion->value;
    const TYPE_SITE = NotificationType::Site->value;
    const TYPE_TRUCK = NotificationType::Truck->value;
    const TYPE_REVIEW = NotificationType::Review->value;
    const TYPE_MESSAGE = NotificationType::Message->value;

    const CHANNEL_PUSH = NotificationChannel::Push->value;
    const CHANNEL_EMAIL = NotificationChannel::Email->value;
    const CHANNEL_SMS = NotificationChannel::Sms->value;
    const CHANNEL_IN_APP = NotificationChannel::InApp->value;

    const PRIORITY_HIGH = NotificationPriority::High->value;
    const PRIORITY_NORMAL = NotificationPriority::Normal->value;
    const PRIORITY_LOW = NotificationPriority::Low->value;

    const DELIVERY_PENDING = NotificationDeliveryStatus::Pending->value;
    const DELIVERY_SENT = NotificationDeliveryStatus::Sent->value;
    const DELIVERY_DELIVERED = NotificationDeliveryStatus::Delivered->value;
    const DELIVERY_FAILED = NotificationDeliveryStatus::Failed->value;

    // Relationships
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    // Scopes
    public function scopeUnread($query)
    {
        return $query->whereNull('read_at');
    }

    public function scopeRead($query)
    {
        return $query->whereNotNull('read_at');
    }

    public function scopeNotExpired($query)
    {
        return $query->where(function ($q) {
            $q->whereNull('expires_at')
                ->orWhere('expires_at', '>', now());
        });
    }

    public function scopeByType($query, $type)
    {
        $value = $type instanceof NotificationType ? $type->value : $type;

        return $query->where('type', $value);
    }

    /** Non-message notifications (bell icon). */
    public function scopeAlerts($query)
    {
        return $query->where(function ($q) {
            $q->whereNull('type')
                ->orWhere('type', '!=', NotificationType::Message->value);
        });
    }

    /** Internal messages (message icon). */
    public function scopeMessages($query)
    {
        return $query->where('type', NotificationType::Message->value);
    }

    public function scopeByChannel($query, $channel)
    {
        return $query->where('channel', $channel);
    }

    public function scopeByPriority($query, $priority)
    {
        return $query->where('priority', $priority);
    }

    public function scopeSent($query)
    {
        return $query->whereIn('delivery_status', [
            NotificationDeliveryStatus::Sent->value,
            NotificationDeliveryStatus::Delivered->value,
        ]);
    }

    public function scopePending($query)
    {
        return $query->where('delivery_status', NotificationDeliveryStatus::Pending->value);
    }

    public function scopeToday($query)
    {
        return $query->whereDate('created_at', today());
    }

    public function scopeRecent($query, $limit = 10)
    {
        return $query->orderBy('created_at', 'desc')->limit($limit);
    }

    // Accessors
    public function getTypeLabelAttribute()
    {
        $type = $this->type;
        if ($type instanceof NotificationType) {
            return $type->label();
        }

        return ucwords(str_replace('_', ' ', (string) $type));
    }

    public function getChannelLabelAttribute()
    {
        $channel = $this->channel;
        $value = $channel instanceof NotificationChannel ? $channel->value : (string) $channel;

        return ucwords(str_replace('_', ' ', $value));
    }

    public function getPriorityLabelAttribute()
    {
        $priority = $this->priority;
        $value = $priority instanceof NotificationPriority ? $priority->value : (string) $priority;

        return ucwords(str_replace('_', ' ', $value));
    }

    public function getDeliveryStatusLabelAttribute()
    {
        $status = $this->delivery_status;
        $value = $status instanceof NotificationDeliveryStatus ? $status->value : (string) $status;

        return ucwords(str_replace('_', ' ', $value));
    }

    public function getIsReadAttribute()
    {
        return !is_null($this->read_at);
    }

    public function getIsExpiredAttribute()
    {
        return $this->expires_at && $this->expires_at < now();
    }

    public function getTimeAgoAttribute()
    {
        return $this->created_at->diffForHumans();
    }

    public function getFormattedDataAttribute()
    {
        return $this->data ? json_encode($this->data, JSON_PRETTY_PRINT) : null;
    }

    // Methods
    public function markAsRead()
    {
        $this->update(['read_at' => now()]);
    }

    public function markAsSent()
    {
        $this->update([
            'delivery_status' => NotificationDeliveryStatus::Sent,
            'sent_at' => now(),
        ]);
    }

    public function markAsDelivered()
    {
        $this->update([
            'delivery_status' => NotificationDeliveryStatus::Delivered,
        ]);
    }

    public function markAsFailed($reason = null)
    {
        $this->update([
            'delivery_status' => NotificationDeliveryStatus::Failed,
            'data' => array_merge($this->data ?? [], ['failure_reason' => $reason]),
        ]);
    }

    public function isRead(): bool
    {
        return !is_null($this->read_at);
    }

    public function isExpired(): bool
    {
        return $this->expires_at && $this->expires_at < now();
    }

    public static function createNotification(
        $userId,
        $title,
        $body,
        NotificationType|string $type = NotificationType::System,
        $data = null,
        NotificationChannel|string $channel = NotificationChannel::InApp,
        NotificationPriority|string $priority = NotificationPriority::Normal,
        $actionUrl = null,
        $imageUrl = null
    ) {
        return static::create([
            'user_id' => $userId,
            'title' => $title,
            'body' => $body,
            'type' => NotificationType::fromMixed($type),
            'data' => $data,
            'channel' => NotificationChannel::fromMixed($channel),
            'priority' => NotificationPriority::fromMixed($priority),
            'action_url' => $actionUrl,
            'image_url' => $imageUrl,
            'delivery_status' => NotificationDeliveryStatus::Pending,
            'expires_at' => now()->addDays(7),
        ]);
    }

    public static function createOrderNotification(
        $userId,
        $order,
        $status,
        $additionalData = null
    ) {
        $messages = [
            'pending' => 'Your order has been placed',
            'confirmed' => 'Your order has been confirmed',
            'processing' => 'Your order is being processed',
            'ready_for_delivery' => 'Your order is ready for delivery',
            'in_transit' => 'Your order is on the way',
            'delivered' => 'Your order has been delivered',
            'completed' => 'Your order is complete',
            'cancelled' => 'Your order has been cancelled',
        ];

        $title = $messages[$status] ?? 'Order Update';
        $body = "Order #{$order->order_number} - {$title}";

        return self::createNotification(
            $userId,
            $title,
            $body,
            NotificationType::Order,
            array_merge([
                'order_id' => $order->id,
                'order_number' => $order->order_number,
                'status' => $status,
                'total' => $order->total_amount,
            ], $additionalData ?? []),
            NotificationChannel::InApp,
            $status === 'cancelled' ? NotificationPriority::High : NotificationPriority::Normal,
            route('orders.show', $order->id)
        );
    }
}
