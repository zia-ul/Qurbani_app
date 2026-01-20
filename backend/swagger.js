const swaggerJSDoc = require('swagger-jsdoc');

const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'Qurbani',
      version: '1.0.0',
      description: 'API documentation for My App',
    },
    servers: [
    //   { url: 'https://api.myapp.com' },
      { url: 'http://localhost:3000' }
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT'
        }
      }
    },
    security: [{ bearerAuth: [] }]
  },
  apis: ['./routes/*.js'], // auto-scan routes
};

module.exports = swaggerJSDoc(options);
