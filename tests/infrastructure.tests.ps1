BeforeAll {
    $ErrorActionPreference = 'Stop'
    $bicepPath = Resolve-Path "$PSScriptRoot/../bicep"
    $parametersPath = Resolve-Path "$PSScriptRoot/../parameters"
}

Describe 'Bicep Infrastructure Tests' {
    
    Context 'Bicep File Validation' {
        
        It 'main.bicep should exist' {
            Test-Path "$bicepPath/main.bicep" | Should -Be $true
        }

        It 'common-mgmt.bicep should exist' {
            Test-Path "$bicepPath/common-mgmt.bicep" | Should -Be $true
        }

        It 'environment.bicep should exist' {
            Test-Path "$bicepPath/environment.bicep" | Should -Be $true
        }

        It 'All Bicep files should have .bicep extension' {
            $bicepFiles = Get-ChildItem -Path $bicepPath -Recurse -Filter "*.bicep"
            $bicepFiles.Count | Should -BeGreaterThan 0
        }

        It 'main.bicep should compile without errors' {
            $result = & bicep build "$bicepPath/main.bicep" 2>&1
            $LASTEXITCODE | Should -Be 0
        }

        It 'common-mgmt.bicep should compile without errors' {
            $result = & bicep build "$bicepPath/common-mgmt.bicep" 2>&1
            $LASTEXITCODE | Should -Be 0
        }

        It 'environment.bicep should compile without errors' {
            $result = & bicep build "$bicepPath/environment.bicep" 2>&1
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context 'Module Files Validation' {
        
        $requiredModules = @(
            'loganalytics/main.bicep',
            'virtualnetwork/main.bicep',
            'virtualnetwork/peering.bicep',
            'keyvault/main.bicep',
            'keyvault/rbac.bicep',
            'webapp/main.bicep',
            'vm/main.bicep',
            'appgateway/main.bicep',
            'privatedns/main.bicep'
        )

        foreach ($module in $requiredModules) {
            It "Module $module should exist" {
                Test-Path "$bicepPath/modules/$module" | Should -Be $true
            }

            It "Module $module should compile without errors" {
                $result = & bicep build "$bicepPath/modules/$module" 2>&1
                $LASTEXITCODE | Should -Be 0
            }
        }
    }

    Context 'Parameter Files Validation' {
        
        $environments = @('dev', 'qa', 'prod')

        foreach ($env in $environments) {
            It "$env.bicepparam should exist" {
                Test-Path "$parametersPath/$env.bicepparam" | Should -Be $true
            }

            It "$env.bicepparam should reference main.bicep" {
                $content = Get-Content "$parametersPath/$env.bicepparam" -Raw
                $content | Should -Match "using.*main\.bicep"
            }

            It "$env.bicepparam should have environment parameter set to $env" {
                $content = Get-Content "$parametersPath/$env.bicepparam" -Raw
                $content | Should -Match "param environment = '$env'"
            }

            It "$env.bicepparam should have primaryRegion parameter" {
                $content = Get-Content "$parametersPath/$env.bicepparam" -Raw
                $content | Should -Match "param primaryRegion"
            }
        }
    }

    Context 'Bicep Metadata Validation' {
        
        $bicepFiles = Get-ChildItem -Path $bicepPath -Recurse -Filter "*.bicep" | Select-Object -First 5

        foreach ($file in $bicepFiles) {
            It "$($file.Name) should have metadata name" {
                $content = Get-Content $file.FullName -Raw
                $content | Should -Match "metadata name"
            }

            It "$($file.Name) should have metadata description" {
                $content = Get-Content $file.FullName -Raw
                $content | Should -Match "metadata description"
            }
        }
    }

    Context 'Required Tags Configuration' {
        
        $requiredTags = @('Owner', 'Environment', 'DeployedDate', 'DeployedBy', 'Platform', 'Notes')

        It 'main.bicep should define commonTags variable' {
            $content = Get-Content "$bicepPath/main.bicep" -Raw
            $content | Should -Match "var commonTags"
        }

        foreach ($tag in $requiredTags) {
            It "main.bicep should include '$tag' in commonTags" {
                $content = Get-Content "$bicepPath/main.bicep" -Raw
                $content | Should -Match $tag
            }
        }

        It 'commonTags should have Owner set to BenTheBuilder' {
            $content = Get-Content "$bicepPath/main.bicep" -Raw
            $content | Should -Match "Owner.*BenTheBuilder"
        }

        It 'commonTags should have Platform set to DemoApp' {
            $content = Get-Content "$bicepPath/main.bicep" -Raw
            $content | Should -Match "Platform.*DemoApp"
        }
    }

    Context 'Network Configuration Validation' {
        
        It 'main.bicep should define management VNet address space' {
            $content = Get-Content "$bicepPath/main.bicep" -Raw
            $content | Should -Match "mgmtVnetAddressSpace"
            $content | Should -Match "10\.90\.0\.0/22"
        }

        It 'main.bicep should define environment-specific VNet address spaces' {
            $content = Get-Content "$bicepPath/main.bicep" -Raw
            $content | Should -Match "envVnetAddressSpace"
            $content | Should -Match "10\.90\.[4-6]\.0/24"
        }

        It 'environment.bicep should configure subnets for private endpoints' {
            $content = Get-Content "$bicepPath/environment.bicep" -Raw
            $content | Should -Match "PrivateEndpoints"
        }

        It 'environment.bicep should configure subnets for app services' {
            $content = Get-Content "$bicepPath/environment.bicep" -Raw
            $content | Should -Match "AppServices"
        }
    }

    Context 'Security Configuration Validation' {
        
        It 'Key Vault module should enable RBAC by default' {
            $content = Get-Content "$bicepPath/modules/keyvault/main.bicep" -Raw
            $content | Should -Match "enableRbacAuthorization.*bool.*true"
        }

        It 'Key Vault module should disable public network access by default' {
            $content = Get-Content "$bicepPath/modules/keyvault/main.bicep" -Raw
            $content | Should -Match "publicNetworkAccess.*string.*Disabled"
        }

        It 'Key Vault module should enable purge protection' {
            $content = Get-Content "$bicepPath/modules/keyvault/main.bicep" -Raw
            $content | Should -Match "enablePurgeProtection"
        }

        It 'Web App module should require HTTPS only' {
            $content = Get-Content "$bicepPath/modules/webapp/main.bicep" -Raw
            $content | Should -Match "httpsOnly.*bool.*true"
        }

        It 'Web App module should use minimum TLS version 1.2' {
            $content = Get-Content "$bicepPath/modules/webapp/main.bicep" -Raw
            $content | Should -Match "minTlsVersion.*1\.2"
        }
    }

    Context 'Diagnostic Settings Validation' {
        
        $modulesWithDiagnostics = @(
            'loganalytics/main.bicep',
            'virtualnetwork/main.bicep',
            'keyvault/main.bicep',
            'webapp/main.bicep',
            'appgateway/main.bicep'
        )

        foreach ($module in $modulesWithDiagnostics) {
            It "Module $module should configure diagnostic settings" {
                $content = Get-Content "$bicepPath/modules/$module" -Raw
                $content | Should -Match "diagnosticSettings|Microsoft\.Insights/diagnosticSettings"
            }

            It "Module $module should reference Log Analytics Workspace" {
                $content = Get-Content "$bicepPath/modules/$module" -Raw
                $content | Should -Match "logAnalyticsWorkspace|workspaceId"
            }
        }
    }

    Context 'Resource Lock Validation' {
        
        $modulesWithLocks = @(
            'loganalytics/main.bicep',
            'virtualnetwork/main.bicep',
            'keyvault/main.bicep',
            'vm/main.bicep'
        )

        foreach ($module in $modulesWithLocks) {
            It "Module $module should configure resource lock" {
                $content = Get-Content "$bicepPath/modules/$module" -Raw
                $content | Should -Match "Microsoft\.Authorization/locks"
            }

            It "Module $module should use CanNotDelete lock level" {
                $content = Get-Content "$bicepPath/modules/$module" -Raw
                $content | Should -Match "level.*CanNotDelete"
            }
        }
    }

    Context 'Output Validation' {
        
        It 'main.bicep should output Log Analytics Workspace ID' {
            $content = Get-Content "$bicepPath/main.bicep" -Raw
            $content | Should -Match "output logAnalyticsWorkspaceId"
        }

        It 'main.bicep should output Web App name' {
            $content = Get-Content "$bicepPath/main.bicep" -Raw
            $content | Should -Match "output webAppName"
        }

        It 'main.bicep should output Key Vault name' {
            $content = Get-Content "$bicepPath/main.bicep" -Raw
            $content | Should -Match "output keyVaultName"
        }

        It 'environment.bicep should output VNet ID' {
            $content = Get-Content "$bicepPath/environment.bicep" -Raw
            $content | Should -Match "output.*VnetId"
        }
    }
}

Describe 'GitHub Actions Workflow Tests' {
    
    Context 'Workflow Files Validation' {
        
        $workflowPath = Resolve-Path "$PSScriptRoot/../.github/workflows"
        
        $requiredWorkflows = @(
            'unit-tests.yml',
            'deploy-dev.yml',
            'deploy-qa.yml',
            'deploy-prod.yml'
        )

        foreach ($workflow in $requiredWorkflows) {
            It "$workflow should exist" {
                Test-Path "$workflowPath/$workflow" | Should -Be $true
            }

            It "$workflow should be valid YAML" {
                $content = Get-Content "$workflowPath/$workflow" -Raw
                $content | Should -Not -BeNullOrEmpty
                # Basic YAML validation - should have 'name:' and 'on:'
                $content | Should -Match "name:"
                $content | Should -Match "on:"
            }
        }

        It 'unit-tests.yml should trigger on pull_request' {
            $content = Get-Content "$workflowPath/unit-tests.yml" -Raw
            $content | Should -Match "pull_request"
        }

        It 'deploy-dev.yml should trigger on push to dev branch' {
            $content = Get-Content "$workflowPath/deploy-dev.yml" -Raw
            $content | Should -Match "push"
            $content | Should -Match "dev"
        }

        It 'deploy-qa.yml should trigger on push to qa branch' {
            $content = Get-Content "$workflowPath/deploy-qa.yml" -Raw
            $content | Should -Match "push"
            $content | Should -Match "qa"
        }

        It 'deploy-prod.yml should trigger on push to main branch' {
            $content = Get-Content "$workflowPath/deploy-prod.yml" -Raw
            $content | Should -Match "push"
            $content | Should -Match "main"
        }
    }

    Context 'Workflow Job Validation' {
        
        $workflowPath = Resolve-Path "$PSScriptRoot/../.github/workflows"

        It 'unit-tests.yml should include lint-and-validate job' {
            $content = Get-Content "$workflowPath/unit-tests.yml" -Raw
            $content | Should -Match "lint-and-validate"
        }

        It 'unit-tests.yml should include what-if-analysis job' {
            $content = Get-Content "$workflowPath/unit-tests.yml" -Raw
            $content | Should -Match "what-if-analysis"
        }

        It 'unit-tests.yml should include pester-tests job' {
            $content = Get-Content "$workflowPath/unit-tests.yml" -Raw
            $content | Should -Match "pester-tests"
        }

        It 'deploy-dev.yml should include validate job' {
            $content = Get-Content "$workflowPath/deploy-dev.yml" -Raw
            $content | Should -Match "validate"
        }

        It 'deploy-dev.yml should include deploy-infrastructure job' {
            $content = Get-Content "$workflowPath/deploy-dev.yml" -Raw
            $content | Should -Match "deploy-infrastructure"
        }

        It 'deploy-dev.yml should include deploy-application job' {
            $content = Get-Content "$workflowPath/deploy-dev.yml" -Raw
            $content | Should -Match "deploy-application"
        }
    }
}

Describe 'Application Tests' {
    
    Context 'Node.js Application Files' {
        
        $appPath = Resolve-Path "$PSScriptRoot/../app"

        It 'package.json should exist' {
            Test-Path "$appPath/package.json" | Should -Be $true
        }

        It 'server.js should exist' {
            Test-Path "$appPath/server.js" | Should -Be $true
        }

        It 'package.json should be valid JSON' {
            $content = Get-Content "$appPath/package.json" -Raw
            { $content | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'package.json should define start script' {
            $package = Get-Content "$appPath/package.json" -Raw | ConvertFrom-Json
            $package.scripts.start | Should -Not -BeNullOrEmpty
        }

        It 'package.json should require Node.js 18 or higher' {
            $package = Get-Content "$appPath/package.json" -Raw | ConvertFrom-Json
            $package.engines.node | Should -Match "18"
        }

        It 'server.js should use express' {
            $content = Get-Content "$appPath/server.js" -Raw
            $content | Should -Match "require.*express"
        }

        It 'server.js should configure health check endpoint' {
            $content = Get-Content "$appPath/server.js" -Raw
            $content | Should -Match "/health"
        }
    }
}
