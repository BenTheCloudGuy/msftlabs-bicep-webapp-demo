const express = require('express');
const { DefaultAzureCredential } = require('@azure/identity');
const { SecretClient } = require('@azure/keyvault-secrets');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 3000;

// Environment variables
const ENVIRONMENT = process.env.ENVIRONMENT || 'unknown';
const KEY_VAULT_NAME = process.env.KEY_VAULT_NAME || '';

// Azure Key Vault client (if configured)
let secretClient = null;
if (KEY_VAULT_NAME) {
  const keyVaultUrl = `https://${KEY_VAULT_NAME}.vault.azure.net`;
  const credential = new DefaultAzureCredential();
  secretClient = new SecretClient(keyVaultUrl, credential);
}

// GitHub repository info (from environment or defaults)
const repoInfo = {
  repository: process.env.GITHUB_REPOSITORY || 'BenTheCloudGuy/msftlabs-intro-to-bicep',
  branch: process.env.GITHUB_REF_NAME || 'main',
  sha: process.env.GITHUB_SHA || 'N/A',
  actor: process.env.GITHUB_ACTOR || 'N/A',
  workflow: process.env.GITHUB_WORKFLOW || 'N/A',
  runNumber: process.env.GITHUB_RUN_NUMBER || 'N/A',
  runId: process.env.GITHUB_RUN_ID || 'N/A'
};

// Middleware
app.use(express.json());
app.use(express.static('public'));

// Routes
app.get('/', (req, res) => {
  const html = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>GitHub WebApp Demo - ${ENVIRONMENT}</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            padding: 40px;
            max-width: 800px;
            width: 100%;
        }
        h1 {
            color: #333;
            margin-bottom: 10px;
            font-size: 2.5em;
        }
        .badge {
            display: inline-block;
            padding: 6px 12px;
            border-radius: 20px;
            font-size: 0.85em;
            font-weight: 600;
            margin-bottom: 30px;
        }
        .badge.dev { background: #10b981; color: white; }
        .badge.qa { background: #f59e0b; color: white; }
        .badge.prod { background: #ef4444; color: white; }
        .section {
            background: #f9fafb;
            border-radius: 10px;
            padding: 20px;
            margin-bottom: 20px;
        }
        .section h2 {
            color: #667eea;
            margin-bottom: 15px;
            font-size: 1.3em;
            display: flex;
            align-items: center;
        }
        .section h2::before {
            content: "";
            margin-right: 10px;
        }
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
        }
        .info-item {
            background: white;
            padding: 15px;
            border-radius: 8px;
            border-left: 4px solid #667eea;
        }
        .info-label {
            color: #6b7280;
            font-size: 0.85em;
            margin-bottom: 5px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        .info-value {
            color: #1f2937;
            font-weight: 600;
            word-break: break-all;
        }
        .status {
            display: flex;
            align-items: center;
            gap: 15px;
            padding: 20px;
            background: #ecfdf5;
            border-radius: 10px;
            border: 2px solid #10b981;
        }
        .status-icon {
            font-size: 2em;
        }
        .status-text {
            flex: 1;
        }
        .status-title {
            color: #065f46;
            font-weight: 700;
            font-size: 1.2em;
        }
        .status-subtitle {
            color: #047857;
            margin-top: 5px;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 2px solid #e5e7eb;
            color: #6b7280;
            font-size: 0.9em;
        }
        .btn {
            display: inline-block;
            padding: 10px 20px;
            background: #667eea;
            color: white;
            text-decoration: none;
            border-radius: 8px;
            margin-top: 10px;
            transition: background 0.3s;
        }
        .btn:hover {
            background: #5568d3;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>GitHub WebApp Demo</h1>
        <span class="badge ${ENVIRONMENT}">${ENVIRONMENT.toUpperCase()} Environment</span>
        
        <div class="status">
            <div class="status-icon">Active</div>
            <div class="status-text">
                <div class="status-title">Application Running Successfully</div>
                <div class="status-subtitle">CI/CD Pipeline deployed via GitHub Actions</div>
            </div>
        </div>

        <div class="section">
            <h2>Environment Information</h2>
            <div class="info-grid">
                <div class="info-item">
                    <div class="info-label">Environment</div>
                    <div class="info-value">${ENVIRONMENT}</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Node Version</div>
                    <div class="info-value">${process.version}</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Platform</div>
                    <div class="info-value">${process.platform}</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Key Vault</div>
                    <div class="info-value">${KEY_VAULT_NAME || 'Not configured'}</div>
                </div>
            </div>
        </div>

        <div class="section">
            <h2>GitHub Repository Info</h2>
            <div class="info-grid">
                <div class="info-item">
                    <div class="info-label">Repository</div>
                    <div class="info-value">${repoInfo.repository}</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Branch</div>
                    <div class="info-value">${repoInfo.branch}</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Deployed By</div>
                    <div class="info-value">${repoInfo.actor}</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Workflow</div>
                    <div class="info-value">${repoInfo.workflow}</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Run Number</div>
                    <div class="info-value">#${repoInfo.runNumber}</div>
                </div>
                <div class="info-item">
                    <div class="info-label">Commit SHA</div>
                    <div class="info-value">${repoInfo.sha.substring(0, 7)}</div>
                </div>
            </div>
            <a href="https://github.com/${repoInfo.repository}/actions/runs/${repoInfo.runId}" class="btn" target="_blank">
                View Deployment in GitHub
            </a>
        </div>

        <div class="footer">
            <strong>GitHub WebApp CI/CD Demo</strong><br>
            Deployed with ❤️ using Bicep IaC and GitHub Actions<br>
            © 2026 BenTheBuilder | Platform: DemoApp
        </div>
    </div>
</body>
</html>
  `;
  res.send(html);
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    environment: ENVIRONMENT,
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage()
  });
});

// API endpoint to get repository info
app.get('/api/info', (req, res) => {
  res.json({
    environment: ENVIRONMENT,
    repository: repoInfo,
    node: {
      version: process.version,
      platform: process.platform,
      arch: process.arch
    },
    keyVault: {
      configured: !!KEY_VAULT_NAME,
      name: KEY_VAULT_NAME
    }
  });
});

// API endpoint to test Key Vault access
app.get('/api/secret', async (req, res) => {
  if (!secretClient) {
    return res.status(503).json({
      error: 'Key Vault not configured',
      message: 'KEY_VAULT_NAME environment variable is not set'
    });
  }

  try {
    const secretName = 'demo-secret';
    const secret = await secretClient.getSecret(secretName);
    res.json({
      success: true,
      message: 'Successfully retrieved secret from Key Vault',
      secretName: secretName,
      secretValue: secret.value,
      environment: ENVIRONMENT
    });
  } catch (error) {
    console.error('Error accessing Key Vault:', error);
    res.status(500).json({
      error: 'Failed to access Key Vault',
      message: error.message
    });
  }
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    path: req.path
  });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({
    error: 'Internal Server Error',
    message: err.message
  });
});

// Start server
app.listen(port, () => {
  console.log(`Server running on port ${port}`);
  console.log(`Environment: ${ENVIRONMENT}`);
  console.log(`Key Vault: ${KEY_VAULT_NAME || 'Not configured'}`);
  console.log(`Repository: ${repoInfo.repository}`);
  console.log(`Branch: ${repoInfo.branch}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully...');
  process.exit(0);
});
