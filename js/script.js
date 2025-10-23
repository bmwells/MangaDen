// Dynamic sizing and responsive behavior
class MangaDenApp {
    constructor() {
        this.init();
    }

    init() {
        this.setupNavigation();
        this.setupSmoothScrolling();
        this.setupAnimations();
        this.handleResize();
    }

    setupNavigation() {
        const hamburger = document.querySelector('.hamburger');
        const navMenu = document.querySelector('.nav-menu');

        if (hamburger && navMenu) {
            hamburger.addEventListener('click', () => {
                hamburger.classList.toggle('active');
                navMenu.classList.toggle('active');
            });
        }

        // Close mobile menu when clicking on links
        const navLinks = document.querySelectorAll('.nav-link');
        navLinks.forEach(link => {
            link.addEventListener('click', () => {
                hamburger.classList.remove('active');
                navMenu.classList.remove('active');
            });
        });
    }

    setupSmoothScrolling() {
        // Smooth scrolling for anchor links
        document.querySelectorAll('a[href^="#"]').forEach(anchor => {
            anchor.addEventListener('click', function (e) {
                e.preventDefault();
                const target = document.querySelector(this.getAttribute('href'));
                if (target) {
                    target.scrollIntoView({
                        behavior: 'smooth',
                        block: 'start'
                    });
                }
            });
        });
    }

    setupAnimations() {
        // Intersection Observer for fade-in animations
        const observerOptions = {
            threshold: 0.1,
            rootMargin: '0px 0px -50px 0px'
        };

        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.classList.add('animate-in');
                }
            });
        }, observerOptions);

        // Observe elements for animation
        document.querySelectorAll('.feature-card, .contact-card, .faq-item').forEach(el => {
            observer.observe(el);
        });
    }

    handleResize() {
        // Handle window resize for dynamic adjustments
        let resizeTimer;
        window.addEventListener('resize', () => {
            clearTimeout(resizeTimer);
            resizeTimer = setTimeout(() => {
                this.adjustLayout();
            }, 250);
        });
    }

    adjustLayout() {
        const screenWidth = window.innerWidth;
        const heroContainer = document.querySelector('.hero-container');
        
        if (heroContainer && screenWidth < 768) {
            // Adjust hero layout for mobile
            const heroContent = heroContainer.querySelector('.hero-content');
            const heroImage = heroContainer.querySelector('.hero-image');
            
            if (heroContent && heroImage) {
                // Ensure proper order for mobile
                heroContainer.style.gridTemplateColumns = '1fr';
                heroContainer.style.gap = '2rem';
            }
        }
    }

    // Utility function for dynamic font sizing
    adjustFontSize() {
        const screenWidth = window.innerWidth;
        const root = document.documentElement;
        
        if (screenWidth < 480) {
            root.style.fontSize = '14px';
        } else if (screenWidth < 768) {
            root.style.fontSize = '15px';
        } else {
            root.style.fontSize = '16px';
        }
    }
}

// Initialize the app when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    const app = new MangaDenApp();
    
    // Initial font size adjustment
    app.adjustFontSize();
    
    // Re-adjust on resize
    window.addEventListener('resize', () => {
        app.adjustFontSize();
    });
});

// Add CSS for animations
const style = document.createElement('style');
style.textContent = `
    .feature-card,
    .contact-card,
    .faq-item {
        opacity: 0;
        transform: translateY(30px);
        transition: all 0.6s ease;
    }
    
    .animate-in {
        opacity: 1;
        transform: translateY(0);
    }
    
    .hamburger.active span:nth-child(1) {
        transform: rotate(45deg) translate(5px, 5px);
    }
    
    .hamburger.active span:nth-child(2) {
        opacity: 0;
    }
    
    .hamburger.active span:nth-child(3) {
        transform: rotate(-45deg) translate(7px, -6px);
    }
    
    @media (max-width: 768px) {
        .nav-menu {
            position: fixed;
            left: -100%;
            top: 70px;
            flex-direction: column;
            background: var(--white);
            width: 100%;
            text-align: center;
            transition: 0.3s;
            box-shadow: var(--shadow);
            padding: 2rem 0;
        }
        
        .nav-menu.active {
            left: 0;
        }
        
        .nav-menu .nav-link {
            padding: 1rem;
            display: block;
        }
    }
`;
document.head.appendChild(style);

// Additional utility functions
const Utils = {
    // Debounce function for performance
    debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    },

    // Throttle function for scroll events
    throttle(func, limit) {
        let inThrottle;
        return function(...args) {
            if (!inThrottle) {
                func.apply(this, args);
                inThrottle = true;
                setTimeout(() => inThrottle = false, limit);
            }
        };
    }
};

// Export for potential module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { MangaDenApp, Utils };
}