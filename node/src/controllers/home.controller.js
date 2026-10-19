exports.index = (req, res) => {
  res.render('home', { titulo: 'Comisiones de dibujos' });
};

exports.health = (req, res) => {
  res.json({ status: 'ok' });
};
