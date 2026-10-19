<?php

declare(strict_types=1);

use App\Controllers\ComisionController;

require_once __DIR__ . '/../src/Controllers/ComisionController.php';

$ruta = trim(parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH) ?? '/', '/');
$controlador = new ComisionController();

if ($ruta === 'comisiones') {
    $controlador->index();
    exit;
}

if (preg_match('#^comisiones/(\d+)$#', $ruta, $coincidencias) === 1) {
    $controlador->show((int) $coincidencias[1]);
    exit;
}

if ($ruta === 'health') {
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['status' => 'ok']);
    exit;
}

if ($ruta !== '') {
    http_response_code(404);
}

require __DIR__ . '/../templates/layout.php';
