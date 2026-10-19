exports.listar = (req, res) => {
  res.render('comisiones/index', {
    titulo: 'Comisiones',
    comisiones: [],
  });
};

exports.detalle = (req, res) => {
  res.render('comisiones/show', {
    titulo: 'Detalle de comisión',
    id: req.params.id,
  });
};

exports.formulario = (req, res) => {
  res.render('comisiones/form', {
    titulo: 'Nueva comisión',
    comision: null,
  });
};

exports.crear = (req, res) => {
  res.redirect('/comisiones');
};

exports.editar = (req, res) => {
  res.render('comisiones/form', {
    titulo: 'Editar comisión',
    comision: null,
    id: req.params.id,
  });
};

exports.actualizar = (req, res) => {
  res.redirect('/comisiones');
};

exports.cambiarEstado = (req, res) => {
  res.redirect('/comisiones');
};
