const swaggerJsdoc = require('swagger-jsdoc');
const path = require('path');

const options = {
    definition: {
        openapi: '3.0.0',
        info: {
            title: 'API Livraison B2B',
            version: '2.0.0',
            description: 'API REST pour la gestion de commandes B2B, livraisons et cafÃ©tÃ©rias.',
            contact: {
                name: 'Support Technique',
                email: 'support@example.com',
            },
        },
        servers: [
            {
                url: 'http://localhost:3000/api/v2',
                description: 'Serveur de dÃ©veloppement',
            },
            {
                url: 'https://api.example.com/api/v2',
                description: 'Serveur de production',
            },
        ],
        components: {
            securitySchemes: {
                bearerAuth: {
                    type: 'http',
                    scheme: 'bearer',
                    bearerFormat: 'JWT',
                },
            },
            schemas: {
                Error: {
                    type: 'object',
                    properties: {
                        status: {
                            type: 'string',
                            example: 'error',
                        },
                        message: {
                            type: 'string',
                            example: 'Une erreur est survenue',
                        },
                    },
                },
            },
        },
        security: [
            {
                bearerAuth: [],
            },
        ],
    },
    // Correct path to route files relative to where index.js is run (root of project usually, but let's be robust)
    // Since this file is in api-v2/config/, we go up one level to api-v2/routes/
    apis: [path.join(__dirname, '../routes/*.js')],
};

const specs = swaggerJsdoc(options);

module.exports = specs;
