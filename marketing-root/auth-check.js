/**
 * Family Site Authentication Check
 * This script must be included in all family site pages
 * Checks if user is authenticated and redirects to gateway if not
 */

(function() {
    'use strict';
    
    const API_BASE = 'https://api.futurelink.zip';
    const GATEWAY_URL = '/family/index.html';
    
    // Get current site ID from URL
    function getCurrentSiteId() {
        const pathMatch = window.location.pathname.match(/\/sites\/([^\/]+)/);
        return pathMatch ? pathMatch[1] : null;
    }
    
    // Site ID to family name mapping
    const siteToFamily = {
        'north570525': 'north',
        'bull683912': 'bull',
        'herrman242585': 'herrman',
        'klingenberg422679': 'klingenberg'
    };
    
    // Check authentication status
    async function checkAuth() {
        try {
            const response = await fetch(`${API_BASE}/me`, {
                credentials: 'include',
                headers: {
                    'Content-Type': 'application/json'
                }
            });
            
            if (response.ok) {
                const userData = await response.json();
                const siteId = getCurrentSiteId();
                const familyName = siteToFamily[siteId];
                
                // Check if user has access to this family
                if (familyName && userData.families && userData.families.includes(familyName)) {
                    // User is authenticated and has access
                    console.log(`✅ Authenticated access to ${familyName} family`);
                    return true;
                } else {
                    console.log(`❌ No access to ${familyName} family`);
                    redirectToGateway('insufficient_access');
                    return false;
                }
            } else if (response.status === 401) {
                // Not authenticated
                console.log('❌ Not authenticated');
                redirectToGateway('authentication_required');
                return false;
            } else {
                console.log('❌ Auth check failed:', response.status);
                redirectToGateway('auth_error');
                return false;
            }
        } catch (error) {
            console.error('Auth check error:', error);
            
            // If API is completely unavailable (404, network error), show warning but don't block access
            if (error.message && (error.message.includes('404') || error.message.includes('Failed to fetch'))) {
                showAuthWarning('API temporarily unavailable. Please contact administrator to set up api.futurelink.zip domain mapping.');
                return false; // Don't block access during API setup
            }
            
            // For other errors, show warning
            showAuthWarning();
            return false;
        }
    }
    
    // Redirect to gateway page with reason
    function redirectToGateway(reason = '') {
        const url = reason ? `${GATEWAY_URL}?reason=${encodeURIComponent(reason)}` : GATEWAY_URL;
        window.location.href = url;
    }
    
    // Show auth warning banner (for network errors)
    function showAuthWarning(message = 'Unable to verify authentication. Please check your connection.') {
        const existingBanner = document.getElementById('auth-warning');
        if (existingBanner) return;
        
        const banner = document.createElement('div');
        banner.id = 'auth-warning';
        banner.style.cssText = `
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            background: #f39c12;
            color: white;
            padding: 10px;
            text-align: center;
            z-index: 9999;
            font-family: Arial, sans-serif;
            font-size: 14px;
        `;
        banner.innerHTML = `
            ⚠️ ${message}
            <button onclick="window.location.reload()" style="background: white; color: #f39c12; border: none; padding: 5px 10px; margin-left: 10px; cursor: pointer; border-radius: 3px;">Retry</button>
        `;
        
        document.body.insertBefore(banner, document.body.firstChild);
        
        // Auto-remove after 10 seconds
        setTimeout(() => {
            if (banner.parentNode) {
                banner.parentNode.removeChild(banner);
            }
        }, 10000);
    }
    
    // Add logout functionality to page
    function addLogoutButton() {
        // Look for existing nav buttons
        const navButtons = document.querySelector('.nav-buttons');
        if (navButtons) {
            const logoutBtn = document.createElement('a');
            logoutBtn.href = '#';
            logoutBtn.className = 'nav-button';
            logoutBtn.innerHTML = '🚪 Logout';
            logoutBtn.style.marginLeft = 'auto';
            logoutBtn.onclick = async function(e) {
                e.preventDefault();
                await logout();
            };
            navButtons.appendChild(logoutBtn);
        }
    }
    
    // Logout function
    async function logout() {
        try {
            await fetch(`${API_BASE}/logout`, {
                method: 'POST',
                credentials: 'include'
            });
        } catch (error) {
            console.error('Logout error:', error);
        }
        
        // Clear any local storage
        localStorage.clear();
        sessionStorage.clear();
        
        // Redirect to gateway
        redirectToGateway('logged_out');
    }
    
    // Main execution
    async function init() {
        // Only run on family site pages
        const siteId = getCurrentSiteId();
        if (!siteId) {
            console.log('Not a family site page, skipping auth check');
            return;
        }
        
        console.log(`🔍 Checking authentication for site: ${siteId}`);
        
        const isAuthenticated = await checkAuth();
        if (isAuthenticated) {
            addLogoutButton();
        }
    }
    
    // Run when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
    
    // Expose logout function globally
    window.familyAuth = {
        logout: logout,
        checkAuth: checkAuth
    };
    
})();