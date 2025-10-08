//
//  MetadataExtractionJavaScript.swift
//  MangaDen
//
//  Created by Brody Wells on 10/7/25.
//

import Foundation

class MetadataExtractionJavaScript {
    static func getMetadataExtractionScript() -> String {
        return """
        (function() {
            const metadata = {
                "title": null,
                "title_image": null,
                "author": null,
                "status": null
            };
            
            // Function to find title in page elements
            const findTitleInPage = () => {
                // Try to find title in common elements
                const titleSelectors = [
                    'h1', 'h2', '.title', '.manga-title', '.comic-title',
                    '.series-title', '.entry-title', '.name', '.heading'
                ];
                
                for (const selector of titleSelectors) {
                    try {
                        const elements = document.querySelectorAll(selector);
                        for (let el of elements) {
                            const text = (el.textContent || '').trim();
                            if (text && text.length > 3) {
                                return text;
                            }
                        }
                    } catch (e) {
                        // Ignore selector errors
                    }
                }
                return null;
            };
            
            // 1. Find title image - more comprehensive search
            const findTitleImage = () => {
                const images = document.querySelectorAll('img');
                let bestImage = null;
                let maxScore = 0;
                
                for (let img of images) {
                    if (img.naturalWidth < 100 || img.naturalHeight < 100) continue;
                    
                    const src = img.src || '';
                    const alt = (img.alt || '').toLowerCase();
                    const className = (img.className || '').toLowerCase();
                    const parentClassName = (img.parentElement?.className || '').toLowerCase();
                    const id = (img.id || '').toLowerCase();
                    
                    // Score based on likelihood of being cover image
                    let score = 0;
                    
                    // Content-based scoring
                    if (src.includes('cover')) score += 30;
                    if (src.includes('title')) score += 25;
                    if (alt.includes('cover')) score += 20;
                    if (alt.includes('title')) score += 15;
                    
                    // Class/ID based scoring
                    if (className.includes('cover')) score += 25;
                    if (className.includes('title')) score += 20;
                    if (id.includes('cover')) score += 20;
                    if (id.includes('title')) score += 15;
                    
                    // Structural scoring
                    if (img.closest('.cover-container, .manga-cover, .comic-cover')) score += 35;
                    if (img.closest('.header, .hero, .banner')) score += 20;
                    
                    // Size scoring
                    const area = img.naturalWidth * img.naturalHeight;
                    score += Math.min(area / 10000, 20); // Max 20 points for size
                    
                    if (score > maxScore) {
                        maxScore = score;
                        bestImage = src;
                    }
                }
                
                return bestImage;
            };
            
            metadata.title_image = findTitleImage();
            
            // 2. Enhanced author finding with multiple strategies
            const findAuthor = () => {
                const authorPatterns = [
                    /Author(?:s|\\(s\\))?\\s*:\\s*([^\\n\\r<]+)/i,
                    /Creator(?:s)?\\s*:\\s*([^\\n\\r<]+)/i,
                    /Writer(?:s)?\\s*:\\s*([^\\n\\r<]+)/i,
                    /By\\s*:\\s*([^\\n\\r<]+?(?=\\s*(?:Chapter|Vol|\\d{4}|$)))/i,
                    /Written by\\s*:\\s*([^\\n\\r<]+)/i,
                    /Story by\\s*:\\s*([^\\n\\r<]+)/i,
                    
                    /Author(?:s|\\(s\\))?\\s+([^\\n\\r<:<]+)/i,
                    /Creator(?:s)?\\s+([^\\n\\r<:<]+)/i,
                    /Writer(?:s)?\\s+([^\\n\\r<:<]+)/i,
                    /By\\s+([^\\n\\r<:<]+?(?=\\s*(?:Chapter|Vol|\\d{4}|$)))/i,
                    /Written by\\s+([^\\n\\r<:<]+)/i,
                    /Story by\\s+([^\\n\\r<:<]+)/i,
                    
                    /\\bAuthor\\b[^:\\n\\r<]*([A-Z][a-z]+(?:\\s+[A-Z][a-z]+)+)/,
                    /\\bCreator\\b[^:\\n\\r<]*([A-Z][a-z]+(?:\\s+[A-Z][a-z]+)+)/,
                    /\\bWriter\\b[^:\\n\\r<]*([A-Z][a-z]+(?:\\s+[A-Z][a-z]+)+)/
                ];
                
                let colonMatches = [];
                let nonColonMatches = [];
                
                const textContent = document.body.innerText || document.body.textContent || '';
                for (let i = 0; i < authorPatterns.length; i++) {
                    const pattern = authorPatterns[i];
                    const match = textContent.match(pattern);
                    if (match && match[1]) {
                        let author = match[1].trim()
                            .replace(/\\([^)]+\\)/g, '')
                            .replace(/\\s*,\\s*.*$/, '')
                            .replace(/\\s+and\\s+.*$/i, '')
                            .replace(/\\s*\\bet al\\b.*$/i, '')
                            .replace(/^\\s*[,-]\\s*/, '')
                            .replace(/[,-]\\s*$/, '')
                            .trim();
                        
                        if (author.length > 3) {
                            if (i < 6) {
                                colonMatches.push(author);
                            } else {
                                nonColonMatches.push(author);
                            }
                        }
                    }
                }
                
                if (colonMatches.length > 0) {
                    return colonMatches[0];
                }
                
                const authorSelectors = [
                    'td:contains("Author:")',
                    'td:contains("Creator:")',
                    'th:contains("Author:")',
                    'th:contains("Creator:")',
                    '[class*="author" i]',
                    '[id*="author" i]',
                    '[class*="creator" i]',
                    '[id*="creator" i]',
                    '.author-name',
                    '.creator-name',
                    '.manga-author',
                    '.comic-author',
                    '.writer',
                    '.artist',
                    '.credit'
                ];
                
                let colonElementMatches = [];
                let nonColonElementMatches = [];
                
                for (const selector of authorSelectors) {
                    try {
                        const elements = document.querySelectorAll(selector);
                        for (let el of elements) {
                            const text = (el.textContent || '').trim();
                            if (text && text.length > 3 && !text.includes('@') && !text.includes('http')) {
                                const words = text.split(/\\s+/);
                                if (words.length >= 2 && words.every(word => word.length > 1)) {
                                    if (selector.includes(':contains(":")') || text.includes(':')) {
                                        const colonIndex = text.indexOf(':');
                                        if (colonIndex !== -1) {
                                            const afterColon = text.substring(colonIndex + 1).trim();
                                            if (afterColon.length > 3) {
                                                colonElementMatches.push(afterColon);
                                            }
                                        } else {
                                            colonElementMatches.push(text);
                                        }
                                    } else {
                                        nonColonElementMatches.push(text);
                                    }
                                }
                            }
                        }
                    } catch (e) {
                    }
                }
                
                if (colonElementMatches.length > 0) {
                    return colonElementMatches[0];
                }
                
                if (nonColonMatches.length > 0) {
                    return nonColonMatches[0];
                }
                
                if (nonColonElementMatches.length > 0) {
                    return nonColonElementMatches[0];
                }
                
                const infoTables = document.querySelectorAll('table.info, table.details, .info-table');
                for (let table of infoTables) {
                    const rows = table.querySelectorAll('tr');
                    for (let row of rows) {
                        const cells = row.querySelectorAll('td, th');
                        if (cells.length >= 2) {
                            const label = (cells[0].textContent || '').toLowerCase();
                            const value = (cells[1].textContent || '').trim();
                            
                            if ((label.includes('author') || label.includes('creator')) && value.length > 3) {
                                if (label.includes(':')) {
                                    return value;
                                } else {
                                    nonColonMatches.push(value);
                                }
                            }
                        }
                    }
                }
                
                if (nonColonMatches.length > 0) {
                    return nonColonMatches[0];
                }
                
                return null;
            };
            
            metadata.author = findAuthor();
            
            // 3. Enhanced status finding - COMPREHENSIVE search
            const findStatus = () => {
                const statusPatterns = [
                    /Status[\\s:]*([^\\n\\r<]+)/i,
                    /\\b(completed|ongoing|releasing|finished|hiatus|dropped|cancelled|discontinued)\\b[^.]*status/i,
                    /status[^.]*\\b(completed|ongoing|releasing|finished|hiatus|dropped|cancelled|discontinued)\\b/i,
                    /Publication[\\s:]*([^\\n\\r<]+)/i,
                    /Release[\\s:]*([^\\n\\r<]+)/i,
                    /Update[\\s:]*([^\\n\\r<]+)/i,
                    /(currently|still)\\s+(ongoing|releasing|publishing)/i,
                    /(has|is)\\s+(completed|finished|dropped|cancelled)/i
                ];

                // Get ALL text content from the entire page
                const textContent = document.body.innerText || document.body.textContent || '';
                
                // Strategy 1: Pattern matching in full text
                for (const pattern of statusPatterns) {
                    const match = textContent.match(pattern);
                    if (match) {
                        let statusText = (match[1] || match[0] || '').toLowerCase().trim();
                        
                        // Clean and normalize the status text
                        statusText = statusText.replace(/[^a-zA-Z\\s]/g, ' ').replace(/\\s+/g, ' ').trim();
                        
                        if (statusText.includes('completed') || statusText.includes('finished') || statusText === 'complete') {
                            return "completed";
                        } else if (statusText.includes('ongoing') || statusText.includes('releasing') || statusText.includes('publishing') || statusText.includes('continuing')) {
                            return "releasing";
                        } else if (statusText.includes('hiatus') || statusText.includes('on hold') || statusText.includes('paused')) {
                            return "hiatus";
                        } else if (statusText.includes('dropped') || statusText.includes('cancelled') || statusText.includes('discontinued') || statusText.includes('axed')) {
                            return "dropped";
                        }
                    }
                }

                // Strategy 2: Search in ALL elements that might contain status
                const statusSelectors = [
                    // General status elements
                    '[class*="status" i]', '[id*="status" i]', '*[class*="state" i]', '*[id*="state" i]',
                    '.status', '.state', '.progress', '.publication', '.release',
                    
                    // Manga/comic specific
                    '.manga-status', '.comic-status', '.series-status', '.title-status',
                    '.status-label', '.status-badge', '.status-indicator', '.status-tag',
                    '.statustext', '.status-text', '.statusinfo',
                    
                    // Info sections
                    '.info', '.information', '.details', '.meta', '.metadata',
                    '.series-info', '.manga-info', '.comic-info', '.title-info',
                    '.info-item', '.info-row', '.detail-item',
                    
                    // Sidebars and info panels
                    '.sidebar', '.side-bar', '.info-panel', '.details-panel',
                    '.right-column', '.left-column', '.main-info',
                    
                    // Table-based info
                    'table', 'tr', 'td', 'th', '.table', '.row', '.cell',
                    
                    // Headers and footers
                    'header', 'footer', '.header', '.footer',
                    '.page-header', '.page-footer', '.content-header',
                    
                    // Specific content areas
                    '.description', '.synopsis', '.summary', '.overview',
                    '.manga-details', '.comic-details', '.series-details',
                    
                    // Buttons and badges
                    '.badge', '.tag', '.label', '.button', '.btn',
                    
                    // Common containers
                    '.container', '.wrapper', '.content', '.main', '.section',
                    '.box', '.panel', '.card', '.widget'
                ];

                // Create a unique selector list
                const uniqueSelectors = [...new Set(statusSelectors)];
                
                for (const selector of uniqueSelectors) {
                    try {
                        const elements = document.querySelectorAll(selector);
                        for (let el of elements) {
                            const text = (el.textContent || '').toLowerCase().trim();
                            if (!text || text.length < 3) continue;
                            
                            // Clean the text
                            const cleanText = text.replace(/[^a-zA-Z\\s]/g, ' ').replace(/\\s+/g, ' ').trim();
                            
                            // Check for status indicators
                            if (cleanText.includes('status:')) {
                                const afterStatus = cleanText.split('status:')[1].trim().split(' ')[0];
                                if (afterStatus.includes('complete')) return "completed";
                                if (afterStatus.includes('ongoing')) return "releasing";
                                if (afterStatus.includes('hiatus')) return "hiatus";
                                if (afterStatus.includes('drop')) return "dropped";
                            }
                            
                            // Direct keyword matching
                            if (cleanText.includes('completed') || cleanText.includes('finished') || cleanText === 'complete') {
                                return "completed";
                            } else if (cleanText.includes('ongoing') || cleanText.includes('releasing') || cleanText.includes('publishing') || cleanText.includes('continuing')) {
                                return "releasing";
                            } else if (cleanText.includes('hiatus') || cleanText.includes('on hold') || cleanText.includes('paused')) {
                                return "hiatus";
                            } else if (cleanText.includes('dropped') || cleanText.includes('cancelled') || cleanText.includes('discontinued') || cleanText.includes('axed')) {
                                return "dropped";
                            }
                            
                            // Check parent elements for context
                            if (el.parentElement) {
                                const parentText = (el.parentElement.textContent || '').toLowerCase();
                                if (parentText.includes('status') && (parentText.includes('complete') || parentText.includes('ongoing'))) {
                                    if (parentText.includes('complete')) return "completed";
                                    if (parentText.includes('ongoing')) return "releasing";
                                }
                            }
                        }
                    } catch (e) {
                        // Ignore selector errors
                    }
                }

                // Strategy 3: Search in data attributes and hidden meta information
                const metaStatusSelectors = [
                    'meta[property*="status" i]', 'meta[name*="status" i]',
                    '[data-status]', '[data-state]', '[data-progress]',
                    '*[content*="completed" i]', '*[content*="ongoing" i]',
                    '*[content*="releasing" i]', '*[content*="finished" i]'
                ];

                for (const selector of metaStatusSelectors) {
                    try {
                        const elements = document.querySelectorAll(selector);
                        for (let el of elements) {
                            const content = el.getAttribute('content') || el.getAttribute('data-status') ||
                                           el.getAttribute('data-state') || el.textContent || '';
                            const statusContent = content.toLowerCase().trim();
                            
                            if (statusContent.includes('completed') || statusContent.includes('finished')) {
                                return "completed";
                            } else if (statusContent.includes('ongoing') || statusContent.includes('releasing')) {
                                return "releasing";
                            } else if (statusContent.includes('hiatus')) {
                                return "hiatus";
                            } else if (statusContent.includes('dropped') || statusContent.includes('cancelled')) {
                                return "dropped";
                            }
                        }
                    } catch (e) {
                        // Ignore selector errors
                    }
                }

                return null;
            };

            metadata.status = findStatus();
            
            // Add title extraction from page as fallback
            metadata.title = findTitleInPage();
            
            return Object.keys(metadata).some(key => metadata[key] !== null) ? metadata : null;
        })();
        """
    }
}
