<?php

declare(strict_types=1);

namespace App\Controllers;

class ComisionController
{
    public function index(): void
    {
        require __DIR__ . '/../../templates/comisiones/index.php';
    }

    public function show(int $id): void
    {
        require __DIR__ . '/../../templates/comisiones/show.php';
    }
}
