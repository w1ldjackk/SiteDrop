<?php

namespace App\Services\Activity;

/**
 * Canonical activity action names used across SiteDrop.
 * Prefer these constants when calling ActivityLogger::log().
 */
final class ActivityActions
{
    // Auth
    public const AUTH_REGISTER = 'auth.register';
    public const AUTH_LOGIN = 'auth.login';
    public const AUTH_LOGOUT = 'auth.logout';
    public const AUTH_PASSWORD_RESET = 'auth.password_reset';
    public const AUTH_PASSWORD_FORGOT = 'auth.password_forgot';
    public const AUTH_OTP_SENT = 'auth.otp_sent';

    // Cart
    public const CART_ADD = 'cart.add';
    public const CART_UPDATE = 'cart.update';
    public const CART_REMOVE = 'cart.remove';
    public const CART_CLEAR = 'cart.clear';

    // Wishlist
    public const WISHLIST_ADD = 'wishlist.added';
    public const WISHLIST_REMOVE = 'wishlist.removed';

    // Checkout / Orders
    public const ORDER_PLACED = 'order.placed';
    public const ORDER_CREATED = 'order.created';
    public const ORDER_STATUS = 'order.status_changed';
    public const ORDER_CANCELLED = 'order.cancelled';

    // Payments
    public const PAYMENT_INITIATED = 'payment.initiated';
    public const PAYMENT_VERIFIED = 'payment.verified';
    public const PAYMENT_FAILED = 'payment.failed';

    // Products
    public const PRODUCT_CREATED = 'product.created';
    public const PRODUCT_UPDATED = 'product.updated';
    public const PRODUCT_DELETED = 'product.deleted';
    public const PRODUCT_AVAILABILITY = 'product.availability_toggled';

    // Profile / Settings
    public const PROFILE_UPDATED = 'profile.updated';
    public const PROFILE_AVATAR = 'profile.avatar_updated';
    public const PROFILE_IDENTITY = 'profile.identity_verified';
    public const SETTINGS_APPEARANCE = 'settings.appearance_updated';
    public const SETTINGS_UPDATED = 'settings.updated';

    // Seller
    public const SELLER_ONBOARDED = 'seller.onboarded';
    public const SELLER_DOCUMENT = 'seller.document_uploaded';
    public const SELLER_APPROVED = 'seller.approved';
    public const SELLER_REJECTED = 'seller.rejected';
    public const SELLER_SUSPENDED = 'seller.suspended';
    public const SELLER_ACTIVATED = 'seller.activated';

    // Delivery
    public const DELIVERY_ASSIGNED = 'delivery.assigned';
    public const DELIVERY_STATUS = 'delivery.status_changed';
    public const DELIVERY_ACCEPTED = 'delivery.accepted';

    // Admin / users
    public const USER_CREATED = 'user.created';
    public const USER_UPDATED = 'user.updated';
    public const USER_DELETED = 'user.deleted';
    public const ROLE_CREATED = 'role.created';
    public const ROLE_UPDATED = 'role.updated';
    public const ROLE_DELETED = 'role.deleted';

    // Sites / trucks (high level)
    public const SITE_CREATED = 'site.created';
    public const SITE_UPDATED = 'site.updated';
    public const SITE_DELETED = 'site.deleted';
    public const TRUCK_CREATED = 'truck.created';
    public const TRUCK_UPDATED = 'truck.updated';
    public const TRUCK_DELETED = 'truck.deleted';
}
