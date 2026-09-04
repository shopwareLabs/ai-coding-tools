<?php
return static function (ContainerConfigurator $c) {
    $a = self::class;
    $b = static::class;
    $c2 = parent::class;
    $d = ContainerConfigurator::class;
};
