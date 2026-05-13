# Railway Deployment Guide - Curatering Backend

## Overview
This guide covers deploying the Curatering Node.js backend to Railway.

## Prerequisites
- Railway account
- PostgreSQL database (Railway or external)
- Git repository with the server code

## Configuration Files Created

### 1. `server/railway.toml`
- Configures Railway to use Nixpacks builder
- Sets health check path to `/health`
- Configures restart policy

### 2. `server/nixpacks.toml`
- Defines Node.js build environment
- Includes PostgreSQL client libraries
- Sets up npm install and start commands

### 3. `server/env.example`
- Template for all required environment variables
- Copy this to configure your Railway environment

## Environment Variables Required

### Database Configuration
```
DATABASE_URL=postgresql://user:password@host:port/database
```
Or individual PG variables:
```
PGHOST=your-db-host
PGPORT=5432
PGUSER=your-db-user
PGPASSWORD=your-db-password
PGDATABASE=your-db-name
```

### Application Configuration
```
NODE_ENV=production
JWT_SECRET=your-super-secret-jwt-key
PORT=3000
```

### Email Service (Gmail)
```
TRANSPORTER_EMAIL=your-email@gmail.com
TRANSPORTER_PASSWORD=your-app-password
```

### AI Service (if using)
```
AI_SERVICE_BASE_URL=https://your-ai-service.railway.app
AI_SERVICE_TOKEN=your-ai-service-token
```

### Optional Services
```
PEXELS_API_KEY=your-pexels-api-key
SEED_SUPER_ADMIN_EMAIL=admin@curatering.com
SEED_SUPER_ADMIN_PASSWORD=secure-password
```

## Deployment Steps

### 1. Push Code to Repository
```bash
git add server/railway.toml server/nixpacks.toml server/env.example
git commit -m "Add Railway configuration"
git push
```

### 2. Create Railway Project
1. Go to [Railway](https://railway.app)
2. Click "New Project"
3. Connect your Git repository
4. Select the `server` directory as the root directory

### 3. Configure Environment Variables
1. In Railway project, go to "Variables" tab
2. Add all required environment variables from `env.example`
3. **Important**: Set `NODE_ENV=production`

### 4. Add PostgreSQL Database (Optional)
If using Railway's managed PostgreSQL:
1. Click "New Service" → "Add Database" → "PostgreSQL"
2. Railway will automatically provide `DATABASE_URL`

### 5. Deploy
1. Railway will automatically deploy on push
2. Monitor deployment logs for any errors
3. Once deployed, test the health endpoint: `https://your-app.railway.app/health`

## Health Check
The application includes a health check endpoint at `/health` that returns:
```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "uptime": 123.45,
  "port": 3000,
  "environment": "production"
}
```

## Troubleshooting

### Common Issues

1. **"require is not defined" Error**
   - ✅ Fixed: Converted all files to ES6 modules
   - Ensure `package.json` has `"type": "module"`

2. **Database Constraint Already Exists**
   - ✅ Fixed: Added error handling for constraint creation
   - Database initialization now retries gracefully

3. **Environment Variables Missing**
   - Check Railway "Variables" tab
   - Ensure no typos in variable names
   - Use `env.example` as reference

4. **Database Connection Failed**
   - Verify `DATABASE_URL` is correct
   - Check if database allows Railway IP addresses
   - Ensure SSL settings match database requirements

### Monitoring
- Check Railway logs for deployment issues
- Use the `/health` endpoint to verify service status
- Monitor database connection logs

## Post-Deployment

1. **Test API Endpoints**
   - Health: `GET /health`
   - Cart API: `GET /api/cart`
   - Authentication endpoints

2. **Verify Database**
   - Check if tables were created
   - Verify super admin account was seeded

3. **Configure Frontend**
   - Update frontend API URLs to point to Railway backend
   - Test integration between frontend and backend

## Production Considerations

1. **Security**
   - Use strong `JWT_SECRET`
   - Enable SSL (automatic on Railway)
   - Don't commit actual `.env` file

2. **Performance**
   - Monitor database connection pool
   - Consider Redis for caching (future enhancement)

3. **Backups**
   - Enable automatic database backups
   - Regularly export critical data

## Support

For Railway-specific issues:
- [Railway Documentation](https://docs.railway.app)
- [Railway Status](https://status.railway.app)

For application issues:
- Check application logs in Railway dashboard
- Verify all environment variables are set
- Test database connection separately
