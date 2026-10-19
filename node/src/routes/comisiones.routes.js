const { Router } = require('express');
const comisionesController = require('../controllers/comisiones.controller');

const router = Router();

router.get('/', comisionesController.listar);
router.get('/nueva', comisionesController.formulario);
router.post('/', comisionesController.crear);
router.get('/:id', comisionesController.detalle);
router.get('/:id/editar', comisionesController.editar);
router.post('/:id', comisionesController.actualizar);
router.post('/:id/estado', comisionesController.cambiarEstado);

module.exports = router;
