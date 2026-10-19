const express = require('express');
const { join } = require('node:path');

const indexRoutes = require('./routes/index.routes');
const comisionesRoutes = require('./routes/comisiones.routes');
const errorMiddleware = require('./middlewares/error.middleware');

const app = express();

app.set('view engine', 'ejs');
app.set('views', join(__dirname, 'views'));

app.use(express.urlencoded({ extended: false }));
app.use(express.static(join(__dirname, 'public')));

app.use('/', indexRoutes);
app.use('/comisiones', comisionesRoutes);

app.use((req, res) => {
  res.status(404).render('404', { titulo: 'Página no encontrada' });
});

app.use(errorMiddleware);

module.exports = app;
