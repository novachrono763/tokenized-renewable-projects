# Carbon Credit Tracking System

## Overview
This feature adds comprehensive carbon credit tracking capabilities to the tokenized renewable energy project platform. The system enables verified carbon credit issuance, ownership management, and retirement tracking for renewable energy projects, providing transparent environmental impact measurement and tradeable carbon offsets.

## Changes Included

### Technical Implementation

**Key Functions Added to renewable-project-manager.clar:**

**Authorization Management:**
- `authorize-verifier` - Authorize carbon credit verifiers with certification levels
- `is-verified-verifier` - Check verifier authorization status  
- `get-verifier-info` - Retrieve verifier certification details

**Carbon Credit Lifecycle:**
- `issue-carbon-credit` - Issue verified carbon credits based on emissions reduction data
- `transfer-carbon-credit` - Transfer credit ownership between parties
- `retire-carbon-credit` - Permanently retire credits to prevent double-counting

**Data Tracking:**
- `get-carbon-credit` - Retrieve complete credit information
- `get-project-carbon-totals` - Project-level carbon impact statistics
- `get-credit-owner` - Current credit ownership details
- `get-next-credit-id` - Next available credit identifier

### Data Structures Added

**Carbon Credits Map:**
- CO2 reduction amounts (6 decimal precision)
- Baseline vs actual emissions data
- Monitoring period tracking
- Verification metadata
- Retirement status and dates

**Project Carbon Totals:**
- Total credits issued/retired per project
- Cumulative CO2 reduction tracking
- Issuance date history

**Verifier Registry:**
- Authorization status and certification levels
- Assignment tracking and permissions

**Ownership Management:**
- Credit ownership chain
- Transfer history with pricing
- Acquisition date tracking

## Key Features

**Verification System:**
- Multi-level verifier certification (Levels 1-3)
- Only authorized verifiers can issue credits
- Transparent verification audit trail

**Emissions Tracking:**
- Baseline vs actual emissions comparison
- Automatic CO2 reduction calculation
- Monitoring period validation
- Support for multiple credit standards (VCS, Gold Standard, etc.)

**Ownership & Trading:**
- Secure credit ownership tracking
- Transfer functionality with optional pricing
- Complete ownership history

**Environmental Integrity:**
- Permanent credit retirement to prevent double-counting
- Retired credits cannot be transferred
- Project-level impact aggregation

**Data Transparency:**
- All operations recorded on-chain
- Immutable verification and ownership records
- Comprehensive read-only functions for data access

## Testing & Validation

✅ **Contract passes clarinet check** - All syntax validation successful
✅ **All npm tests successful** - 6/6 tests passing across 3 test files  
✅ **CI/CD pipeline configured** - GitHub Actions workflow for automated validation
✅ **Clarity v3 compliant** - Uses proper data types, error constants, and best practices

### Test Coverage
- Verifier authorization and permission management
- Carbon credit issuance with validation
- Credit transfer and ownership management
- Credit retirement and double-spending prevention
- Read-only function validation
- Error handling for edge cases

## Environmental Impact
This carbon credit system enables:
- **Verified CO2 reduction tracking** from renewable energy projects
- **Transparent environmental accounting** with immutable blockchain records
- **Carbon offset marketplace** functionality for trading verified credits
- **Double-counting prevention** through permanent credit retirement
- **Project impact aggregation** for community-level environmental reporting
