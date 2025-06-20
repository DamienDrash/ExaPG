# Contributing to ExaPG

Thank you for your interest in contributing to ExaPG! We welcome contributions from the community and are excited to see what you'll help us build.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [How to Contribute](#how-to-contribute)
- [Pull Request Process](#pull-request-process)
- [Development Guidelines](#development-guidelines)
- [Testing](#testing)
- [Documentation](#documentation)
- [Community](#community)

## Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to [dfrigewski@gmail.com].

## Getting Started

### Prerequisites

- Docker (19.03 or higher)
- Docker Compose (1.27 or higher)
- Git
- Basic knowledge of PostgreSQL and Docker
- Familiarity with analytical databases is helpful

### First Time Setup

1. **Fork the repository**
   ```bash
   # Go to https://github.com/DamienDrash/ExaPG and click "Fork"
   ```

2. **Clone your fork**
   ```bash
   git clone https://github.com/YOUR-USERNAME/ExaPG.git
   cd ExaPG
   ```

3. **Add upstream remote**
   ```bash
   git remote add upstream https://github.com/DamienDrash/ExaPG.git
   ```

4. **Verify the setup**
   ```bash
   ./scripts/run-all-tests.sh
   ```

## Development Setup

### Environment Configuration

1. **Copy environment template**
   ```bash
   cp .env.template .env
   # Edit .env with your preferences
   ```

2. **Validate configuration**
   ```bash
   # Run configuration validation
   ./scripts/validate-env.sh
   
   # Check all configurations
   ./scripts/validate-config.sh all
   ```

3. **Start development environment**
   ```bash
   # Interactive CLI (recommended)
   ./scripts/cli/exapg-cli.sh
   
   # Or direct start
   ./start-exapg.sh
   ```

4. **Verify installation**
   ```bash
   # Run comprehensive tests
   ./scripts/run-tests.sh
   
   # Test specific components
   ./scripts/test-exapg.sh
   ```

### Development Tools

**Recommended tools:**
- **Database Client**: pgAdmin, DBeaver, or psql
- **Editor**: VS Code with PostgreSQL extensions
- **Docker**: Docker Desktop or CLI tools
- **Performance**: Grafana dashboards (http://localhost:3000)

## How to Contribute

### Types of Contributions

We welcome various types of contributions:

- **🐛 Bug Reports** - Help us identify and fix issues
- **✨ Feature Requests** - Suggest new functionality
- **📚 Documentation** - Improve guides, tutorials, and API docs
- **🔧 Code Contributions** - Fix bugs, add features, improve performance
- **🧪 Testing** - Add test cases, improve test coverage (target: 95%+)
- **💡 Ideas & Discussion** - Participate in architectural discussions
- **☸️ Kubernetes** - Improve K8s manifests, operators, cloud-native features
- **🔒 Security** - Security audits, vulnerability fixes, hardening
- **🌍 Internationalization** - Add language support, improve translations
- **🎨 UI/UX Design** - Improve Nord Theme Enhanced, accessibility, visual design

### Finding Issues to Work On

1. **Good First Issues**: Look for issues labeled [`good first issue`](https://github.com/DamienDrash/ExaPG/labels/good%20first%20issue)
2. **Help Wanted**: Check [`help wanted`](https://github.com/DamienDrash/ExaPG/labels/help%20wanted) label
3. **Current Roadmap**: Review [README.md#roadmap](README.md#roadmap) for planned features
4. **Performance**: Benchmark testing and optimization are always welcome

### Reporting Bugs

**Before creating a bug report:**
- Check if the issue already exists
- Test with the latest version
- Gather system information

**Bug report template:**
```markdown
**Environment:**
- ExaPG Version: [e.g., 2.0.0]
- OS: [e.g., Ubuntu 22.04]
- Docker Version: [e.g., 20.10.12]

**Description:**
[Clear description of the bug]

**Steps to Reproduce:**
1. Start ExaPG with `./start-exapg.sh`
2. Execute query: `SELECT ...`
3. Observe error

**Expected Behavior:**
[What should happen]

**Actual Behavior:**
[What actually happens]

**Logs:**
```
[Include relevant logs from docker-compose logs]
```
```

### Suggesting Features

**Feature request template:**
```markdown
**Feature Description:**
[Clear description of the proposed feature]

**Use Case:**
[Why is this feature needed? What problem does it solve?]

**Proposed Solution:**
[How would you like this to be implemented?]

**Alternatives Considered:**
[Any alternative solutions you've considered]

**Additional Context:**
[Any other context, screenshots, or examples]
```

## Pull Request Process

### Before Submitting

1. **Create a branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/issue-number-description
   ```

2. **Make your changes**
   - Follow our [coding standards](#development-guidelines)
   - Add tests for new functionality
   - Update documentation as needed

3. **Test your changes**
   ```bash
   # Run all tests
   ./scripts/run-all-tests.sh
   
   # Test specific areas
   ./scripts/test-performance.sh medium
   ```

4. **Update documentation**
   - Update README.md if needed
   - Add/update inline code comments
   - Update relevant docs/ files

### Submitting the Pull Request

1. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: add new feature description"
   # Follow conventional commits format
   ```

2. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

3. **Create Pull Request**
   - Use the GitHub interface to create a PR
   - Fill out the PR template completely
   - Link to any related issues

### Pull Request Requirements

- ✅ All tests pass
- ✅ Documentation updated
- ✅ Code follows style guidelines
- ✅ Commit messages are descriptive
- ✅ PR description explains the changes
- ✅ Related issues are linked

## Development Guidelines

### Code Style

**PostgreSQL/SQL:**
- Use ANSI SQL standards where possible
- Consistent indentation (2 spaces)
- Descriptive table and column names
- Add comments for complex queries

**Shell Scripts:**
- Follow bash best practices
- Use proper error handling (`set -e`)
- Add usage documentation
- Consistent variable naming

**Docker:**
- Multi-stage builds where appropriate
- Minimize image layers
- Use official base images
- Include health checks

### Git Workflow

**Branch Naming:**
- `feature/description` - New features
- `fix/issue-number` - Bug fixes
- `docs/description` - Documentation updates
- `test/description` - Test improvements

**Commit Messages:**
Follow [Conventional Commits](https://www.conventionalcommits.org/):
```
type(scope): description

feat(cli): add new benchmark command
fix(docker): resolve memory limit issue
docs(readme): update installation guide
test(performance): add TPC-H scale tests
```

### Database Development

**Schema Changes:**
- Always provide migration scripts
- Test with sample data
- Consider performance impact
- Document breaking changes

**Performance:**
- Benchmark new features
- Include EXPLAIN ANALYZE for complex queries
- Test with multiple data sizes
- Monitor memory usage

### UI/UX Development

**Nord Theme Enhanced:**
- Follow semantic color strategy (6-color system)
- Maintain visual hierarchy (4 levels)
- Test accessibility (WCAG compliance)
- Ensure terminal compatibility (256-color support)

**Theme Development:**
```bash
# Test theme changes
./scripts/cli/nord-theme-enhanced.sh

# Validate color accessibility
# Check contrast ratios (minimum 4.5:1)
# Test with different terminal emulators
```

**Color Guidelines:**
- 🔵 **CYAN** - Primary actions, navigation, titles
- 🔷 **BLUE** - Structural elements, borders, management
- 🟢 **GREEN** - Success, positive actions, OK buttons
- 🟡 **YELLOW** - Warnings, shortcuts, attention
- 🔴 **RED** - Errors, critical actions, exit warnings
- 🟣 **MAGENTA** - Info, help, special functions

## Testing

### Test Categories

1. **Unit Tests** - Test individual components (BATS framework)
2. **Integration Tests** - Test component interactions  
3. **Performance Tests** - Benchmark and regression testing
4. **End-to-End Tests** - Full workflow testing
5. **Security Tests** - Vulnerability scanning and compliance
6. **Configuration Tests** - Validate configurations (100+ rules)

### Running Tests

```bash
# All tests with BATS framework
./scripts/run-tests.sh

# Specific test suites
./scripts/run-tests.sh unit          # Unit tests only
./scripts/run-tests.sh integration   # Integration tests
./scripts/run-tests.sh e2e          # End-to-end tests
./scripts/run-tests.sh config       # Configuration validation

# Legacy test scripts (still supported)
./scripts/test-exapg.sh           # Core functionality
./scripts/test-fdw.sh             # Foreign data wrappers
./scripts/test-etl.sh             # ETL processes
./scripts/test-performance.sh     # Performance benchmarks

# Kubernetes tests
cd k8s
./deploy.sh dev --dry-run         # Deployment validation

# Benchmark suite
./benchmark-suite                 # Interactive benchmarks
./benchmark/scripts/benchmark-tests.sh tpch  # TPC-H tests
```

### Test Coverage

Current test coverage statistics:
- **Core Functions**: 95%+ coverage
- **Critical Paths**: 100% coverage  
- **Total Tests**: 175+ automated tests
- **Configuration Rules**: 100+ validation rules
- **UI Scenarios**: 100% functionality verified (6 major areas, 50+ features)
- **Production Readiness**: ✅ Fully verified with live database testing

## Documentation

### Documentation Standards

- **Clear and concise** - Explain concepts simply
- **Examples included** - Provide working code examples
- **Up-to-date** - Keep docs synchronized with code
- **Comprehensive** - Cover all major features

### Documentation Structure

```
docs/
├── INDEX.md                     # Central navigation
├── user-guide/                  # User documentation (5 files)
│   ├── getting-started.md       # Quick start tutorial
│   ├── installation.md          # Detailed setup guide
│   ├── cli-reference.md         # CLI documentation
│   ├── troubleshooting.md       # Problem solving
│   └── migration-guide.md       # Migration from Exasol
├── technical/                   # Technical details (5 files)
│   ├── architecture.md          # System architecture
│   ├── analysis-report.md       # Technical analysis
│   ├── performance-tuning.md    # Optimization guide
│   ├── columnar-storage.md      # Columnar features
│   └── columnar-comparison.md   # Performance comparisons
├── integration/                 # Integration guides (3 files)
│   ├── data-integration.md      # FDW and ETL
│   ├── monitoring.md            # Monitoring setup
│   └── sql-compatibility.md     # SQL compatibility
└── images/                      # Diagrams and images
```

### Writing Documentation

1. **Follow the style guide**
   - Use proper markdown formatting
   - Include code examples
   - Add table of contents for long documents

2. **Test your examples**
   - Verify all code examples work
   - Include expected output
   - Test installation instructions

3. **Update cross-references**
   - Update docs/INDEX.md if needed
   - Add links between related documents
   - Update the main README.md

## Community

### Communication Channels

- **GitHub Issues** - Bug reports and feature requests
- **GitHub Discussions** - General discussion and questions
- **Pull Requests** - Code review and collaboration

### Getting Help

1. **Check existing documentation** - [docs/INDEX.md](docs/INDEX.md)
2. **Search existing issues** - Someone might have the same question
3. **Ask in discussions** - Community Q&A
4. **Contact maintainers** - For complex architectural questions

### Recognition

We appreciate all contributions! Contributors will be:
- Added to the contributor list
- Mentioned in release notes
- Invited to join the contributor team (for regular contributors)

---

## Thank You! 🎉

Thank you for contributing to ExaPG! Your efforts help make high-performance analytics accessible to everyone.

**Questions?** Open a [GitHub Discussion](https://github.com/DamienDrash/ExaPG/discussions) or create an issue.

**ExaPG v3.2.2** ist eine professionell organisierte Open-Source-Projekt mit modernem UI-Design und vollständiger Dokumentation. 
