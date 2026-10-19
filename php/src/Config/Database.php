<?php

declare(strict_types=1);

namespace App\Config;

use PDO;

class Database
{
    public static function connection(): PDO
    {
        $dsn = sprintf(
            'pgsql:host=%s;port=%s;dbname=%s',
            getenv('DB_HOST') ?: 'db',
            getenv('DB_PORT') ?: '5432',
            getenv('DB_NAME') ?: 'comisiones'
        );

        return new PDO(
            $dsn,
            getenv('DB_USER') ?: 'comisiones',
            getenv('DB_PASSWORD') ?: 'comisiones_dev'
        );
    }
}
