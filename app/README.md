# GitHub WebApp Demo - Node.js Application

This is a simple Node.js web application that demonstrates CI/CD deployment with GitHub Actions and Azure.

## Features

- Express.js web server
- Azure Key Vault integration
- Displays GitHub repository information
- Health check endpoint
- REST API endpoints
- Managed Identity authentication

## Local Development

### Prerequisites

- Node.js 18 LTS or higher
- npm

### Setup

1. Install dependencies:
```bash
npm install
```

2. Copy `.env.example` to `.env` and configure:
```bash
cp .env.example .env
```

3. Start the development server:
```bash
npm run dev
```

4. Open your browser to `http://localhost:3000`

## API Endpoints

- `GET /` - Home page with application info
- `GET /health` - Health check endpoint
- `GET /api/info` - Repository and environment information
- `GET /api/secret` - Test Key Vault access (requires Azure authentication)

## Environment Variables

- `PORT` - Server port (default: 3000)
- `ENVIRONMENT` - Deployment environment (dev/qa/prod)
- `KEY_VAULT_NAME` - Azure Key Vault name
- `GITHUB_*` - GitHub Actions variables (set automatically)

## Deployment

This application is deployed automatically via GitHub Actions workflows:
- Dev environment: Push to `dev` branch
- QA environment: Push to `qa` branch
- Production: Push to `main` branch

## Azure Configuration

The application uses:
- Azure App Service (Linux, Node.js 18 LTS)
- System-assigned Managed Identity
- Azure Key Vault for secrets
- Virtual Network integration
- Private endpoints

## License

MIT
