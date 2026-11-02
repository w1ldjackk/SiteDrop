<?php

namespace App\Enums;

trait EnumHelpers
{
    /**
     * @return list<string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }

    public static function fromMixed(self|string $value): self
    {
        if ($value instanceof self) {
            return $value;
        }

        return self::from($value);
    }

    public static function tryFromMixed(self|string|null $value): ?self
    {
        if ($value === null) {
            return null;
        }

        if ($value instanceof self) {
            return $value;
        }

        return self::tryFrom($value);
    }

    public function label(): string
    {
        return ucwords(str_replace(['_', '-'], ' ', $this->value));
    }

    /**
     * @return array<string, string> value => label
     */
    public static function options(): array
    {
        $out = [];
        foreach (self::cases() as $case) {
            $out[$case->value] = $case->label();
        }

        return $out;
    }

    public function is(self|string $other): bool
    {
        if ($other instanceof self) {
            return $this === $other;
        }

        return $this->value === $other;
    }
}
