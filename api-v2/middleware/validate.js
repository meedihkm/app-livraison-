const { z } = require('zod');
const schemas = require('../schemas/validation');

// Middleware de validation du body avec Zod
const validate = (schemaName) => (req, res, next) => {
  const schema = schemas[schemaName];
  if (!schema) {
    console.error(`Schema '${schemaName}' non trouvÃ©`);
    return res.status(500).json({ error: 'Erreur de configuration serveur' });
  }
  
  try {
    schema.parse(req.body);
    next();
  } catch (error) {
    if (error instanceof z.ZodError) {
      const messages = error.errors.map(e => e.message).join(', ');
      return res.status(400).json({ error: messages });
    }
    return res.status(400).json({ error: 'DonnÃ©es invalides' });
  }
};

// Middleware de validation des paramÃ¨tres UUID
const validateUUID = (paramName = 'id') => (req, res, next) => {
  const value = req.params[paramName];
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  
  if (!value || !uuidRegex.test(value)) {
    return res.status(400).json({ error: `${paramName} invalide (UUID requis)` });
  }
  
  next();
};

// Middleware de validation des query params
const validateQuery = (schema) => (req, res, next) => {
  try {
    schema.parse(req.query);
    next();
  } catch (error) {
    if (error instanceof z.ZodError) {
      const messages = error.errors.map(e => e.message).join(', ');
      return res.status(400).json({ error: messages });
    }
    return res.status(400).json({ error: 'ParamÃ¨tres invalides' });
  }
};

module.exports = {
  validate,
  validateUUID,
  validateQuery,
};
