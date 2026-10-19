const { Router } = require('express');
const homeController = require('../controllers/home.controller');

const router = Router();

router.get('/', homeController.index);
router.get('/health', homeController.health);

module.exports = router;
