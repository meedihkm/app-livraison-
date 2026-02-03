/**
 * Configuration PostgreSQL sÃ©curisÃ©e pour AWID API v2
 * SSL requis en production avec validation de certificat
 */

const { Pool } = require('pg');
const fs = require('fs');

// Configuration SSL selon l'environnement
const getSSLConfig = () => {
  const isProduction = process.env.NODE_ENV === 'production';

  if (!isProduction) {
    // DÃ©veloppement: SSL optionnel
    return false;
  }

  // Production: SSL obligatoire
  const sslConfig = {
    // Par dÃ©faut, valider le certificat du serveur
    rejectUnauthorized: process.env.DATABASE_SSL_REJECT_UNAUTHORIZED !== 'false'
  };

  // Support certificat CA personnalisÃ© (pour Neon, Supabase avec CA propre)
  const caPath = process.env.DATABASE_SSL_CA;
  if (caPath) {
    try {
      sslConfig.ca = fs.readFileSync(caPath, 'utf8');
      console.log('[DB] Certificat CA chargÃ© depuis:', caPath);
    } catch (err) {
      console.error('[DB] Erreur lecture certificat CA:', err.message);
      // Continuer sans CA personnalisÃ©
    }
  }

  // Si rejectUnauthorized est dÃ©sactivÃ©, avertir
  if (!sslConfig.rejectUnauthorized) {
    console.warn('[SECURITY] DATABASE_SSL_REJECT_UNAUTHORIZED=false - Validation SSL dÃ©sactivÃ©e');
    console.warn('[SECURITY] Ceci expose Ã  des attaques MITM - Configurer un certificat CA en production');
  }

  return sslConfig;
};

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: getSSLConfig(),

  // Pool configuration optimisÃ©
  max: parseInt(process.env.DATABASE_POOL_MAX) || 20,
  idleTimeoutMillis: 30000, // Fermer les connexions inactives aprÃ¨s 30s
  connectionTimeoutMillis: 2000, // Timeout rapide si le pool est plein ou DB down
  allowExitOnIdle: false,

  // Statement timeout (protection contre requÃªtes longues)
  statement_timeout: 30000,

  // Query timeout
  query_timeout: 30000
});

// Events de connexion (sans console.log en prod)
pool.on('connect', (client) => {
  if (process.env.NODE_ENV !== 'production') {
    console.log('[DB] Nouvelle connexion PostgreSQL Ã©tablie');
  }

  // VÃ©rifier si SSL est actif
  client.query('SHOW ssl').then(result => {
    if (result.rows[0]?.ssl === 'on') {
      if (process.env.NODE_ENV !== 'production') {
        console.log('[DB] Connexion SSL active');
      }
    }
  }).catch(() => {
    // Ignorer si la commande n'est pas supportÃ©e
  });
});

pool.on('error', (err, client) => {
  console.error('[DB] Erreur PostgreSQL inattendue:', err.message);

  // Ne pas crasher en production, mais logger
  if (process.env.NODE_ENV === 'production') {
    // TODO: Envoyer Ã  un service de monitoring (Sentry, etc.)
  }
});

// Fonction utilitaire pour tester la connexion
const testConnection = async () => {
  try {
    const client = await pool.connect();
    const result = await client.query('SELECT NOW() as time, current_database() as db');
    client.release();

    console.log(`[DB] Connexion vÃ©rifiÃ©e - Base: ${result.rows[0].db}`);
    return true;
  } catch (err) {
    console.error('[DB] Ã‰chec connexion:', err.message);
    return false;
  }
};

module.exports = pool;
module.exports.testConnection = testConnection;
