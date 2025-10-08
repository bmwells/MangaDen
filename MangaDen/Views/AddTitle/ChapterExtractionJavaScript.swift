//
//  ChapterExtractionJavaScript.swift
//  MangaDen
//
//  Created by Brody Wells on 10/7/25.
//

import Foundation

class ChapterExtractionJavaScript {
    static func getChapterExtractionScript() -> String {
        return """
        (function() {
            const links = document.querySelectorAll('a');
            const chapterLinks = {};
            
            // Enhanced date patterns including M/DD/YYYY format
            const datePatterns = [
                /\\b\\d{1,2}\\/\\d{1,2}\\/\\d{4}\\b/, // M/DD/YYYY or MM/DD/YYYY
                /\\b\\d{1,2}\\/\\d{1,2}\\/\\d{2}\\b/, // M/DD/YY or MM/DD/YY
                /\\b\\d{1,2}[\\-]\\d{1,2}[\\-]\\d{4}\\b/, // MM-DD-YYYY, M-DD-YYYY
                /\\b\\d{4}[\\-]\\d{1,2}[\\-]\\d{1,2}\\b/, // YYYY-MM-DD
                /(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\\s+\\d{1,2},?\\s+\\d{4}/i,
                /\\d{1,2}\\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\\s+\\d{4}/i,
                /(?:today|yesterday)\\b/i,
                /\\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\\s+\\d{1,2},\\s+\\d{4}\\b/i // NEW: "Oct 7, 2025" format
            ];
        
        // NEW: Time-based patterns to remove from titles (hours ago, days ago, etc.)
                const timePatterns = [
                    /\\s*\\d+\\s+hours?\\s+ago\\s*/i,
                    /\\s*\\d+\\s+hrs?\\s+ago\\s*/i,
                    /\\s*\\d+\\s+days?\\s+ago\\s*/i,
                    /\\s*\\d+\\s+minutes?\\s+ago\\s*/i,
                    /\\s*\\d+\\s+mins?\\s+ago\\s*/i,
                    /\\s*\\d+\\s+seconds?\\s+ago\\s*/i,
                    /\\s*just\\s+now\\s*/i,
                    /\\s*\\d+[hdwm]\\s+ago\\s*/i, // 1h ago, 2d ago, etc.
                ];
                
                // NEW: Function to calculate actual date from relative time
                const calculateDateFromRelativeTime = (relativeTime) => {
                    const now = new Date();
                    const lowerTime = relativeTime.toLowerCase();
                    
                    // Extract number and unit
                    const timeMatch = lowerTime.match(/(\\d+)\\s*(hour|hr|minute|min|second|sec|day|week|month|year|h|d|w|m|y)s?\\s+ago/i);
                    if (!timeMatch) {
                        if (lowerTime.includes('just now')) {
                            // For "just now", return today's date without time
                            return formatDateWithoutTime(now);
                        }
                        return null;
                    }
                    
                    const amount = parseInt(timeMatch[1]);
                    const unit = timeMatch[2].toLowerCase();
                    const result = new Date(now);
                    
                    switch(unit) {
                        case 'minute': case 'min':
                        case 'second': case 'sec':
                            // For minutes/seconds, just return today's date
                            return formatDateWithoutTime(now);
                        case 'hour': case 'hr': case 'h':
                            result.setHours(now.getHours() - amount);
                            break;
                        case 'day': case 'd':
                            result.setDate(now.getDate() - amount);
                            break;
                        case 'week': case 'w':
                            result.setDate(now.getDate() - (amount * 7));
                            break;
                        case 'month': case 'm':
                            result.setMonth(now.getMonth() - amount);
                            break;
                        case 'year': case 'y':
                            result.setFullYear(now.getFullYear() - amount);
                            break;
                        default:
                            return null;
                    }
                    
                    // Return only the date part without time
                    return formatDateWithoutTime(result);
                };
                
                // NEW: Helper function to format date without time
                const formatDateWithoutTime = (date) => {
                    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                    const month = months[date.getMonth()];
                    const day = date.getDate();
                    const year = date.getFullYear();
                    return `${month} ${day}, ${year}`;
                };
        
                // NEW: Function to extract relative time from text
                const extractRelativeTime = (text) => {
                    const patterns = [
                        /(\\d+\\s+hours?\\s+ago)/i,
                        /(\\d+\\s+hrs?\\s+ago)/i,
                        /(\\d+\\s+days?\\s+ago)/i,
                        /(\\d+\\s+minutes?\\s+ago)/i,
                        /(\\d+\\s+mins?\\s+ago)/i,
                        /(\\d+\\s+seconds?\\s+ago)/i,
                        /(just\\s+now)/i,
                        /(\\d+[hdwm]\\s+ago)/i,
                    ];
                    
                    for (const pattern of patterns) {
                        const match = text.match(pattern);
                        if (match && match[1]) {
                            return match[1].trim();
                        }
                    }
                    return null;
                };
        
            // Pattern to exclude titles with numbers in parentheses (e.g., "Iron Man (2016)")
            const excludePattern = /\\(\\s*\\d{4}\\s*\\)|\\(\\s*\\d+\\s*\\)/;
            
            // Patterns to include special chapter identifiers
            const specialChapterPatterns = [
                /\\bFull\\b/i, // Matches "Full" word
                /\\(Part\\s+\\d+\\)/i, // Matches "(Part 1)", "(Part 2)", etc.
                /\\(Pt\\.\\s+\\d+\\)/i, // Matches "(Pt. 1)", "(Pt. 2)", etc.
                /\\bTPB\\b/i, // Matches "TPB" word
                /\\bOmnibus\\b/i, // Matches "Omnibus" word
                /\\bSpecial\\b/i, // Matches "Special" word
                /\\bOne[\\-\\s]?Shot\\b/i, // Matches "One-Shot", "One Shot"
                /\\bExtra\\b/i, // Matches "Extra" word
                /\\bBonus\\b/i // Matches "Bonus" word
            ];
            
            // Get current page URL to filter same-series chapters
            const currentUrl = window.location.href;
            let currentMangaId = null;
            
            // Extract manga ID from current URL (common patterns for manga sites)
            const urlPatterns = [
                /\\/manga\\/([^\\/]+)/,
                /\\/series\\/([^\\/]+)/,
                /\\/comic\\/([^\\/]+)/,
                /\\/title\\/([^\\/]+)/,
                /\\/read\\/([^\\/]+)/,
                /manga=([^&]+)/,
                /series=([^&]+)/,
                /comic=([^&]+)/
            ];
            
            for (const pattern of urlPatterns) {
                const match = currentUrl.match(pattern);
                if (match && match[1]) {
                    currentMangaId = match[1];
                    break;
                }
            }
            
            // If we can't extract a clean ID, use a simpler approach
            if (!currentMangaId) {
                // Use domain and path to create a base pattern
                const urlObj = new URL(currentUrl);
                const pathParts = urlObj.pathname.split('/').filter(part => part.length > 2);
                if (pathParts.length > 0) {
                    currentMangaId = pathParts[pathParts.length - 1];
                }
            }
            
            // First, check if there's a table with chapter/date structure
            const tableDateMap = findDatesInTables();
            
            // NEW: Store links that might be title-only chapters
            const potentialTitleOnlyLinks = [];
            
            // NEW: First try to find the specific site structure (div.flex.items-center with x-data)
            const chapterContainers = document.querySelectorAll('div.flex.items-center');
            let foundSpecificStructure = false;
            
            for (let container of chapterContainers) {
                // Check if this container has the x-data attribute pattern for chapters
                const xData = container.getAttribute('x-data');
                if (xData && xData.includes('new_chapter') && xData.includes('checkNewChapter')) {
                    // Find the anchor tag inside this container
                    const link = container.querySelector('a[href*="/chapters/"]');
                    if (link) {
                        foundSpecificStructure = true;
                        const href = link.href;
                        const text = (link.textContent || link.innerText || '').trim();
                        
                        if (!text || !href) continue;
                        
                        // Skip titles with numbers in parentheses
                        if (excludePattern.test(text)) {
                            continue;
                        }
                        
                        // Filter out links from different manga series
                        if (currentMangaId && !href.includes(currentMangaId)) {
                            continue;
                        }
                        
                        // Extract chapter number from the text
                        let chapterNumber = null;
                        let cleanTitle = text;
                        
                        // Pattern to extract chapter number
                        const chapterPattern = /Chapter\\s+(\\d+(?:\\.\\d+)?)/i;
                        const match = text.match(chapterPattern);
                        if (match && match[1]) {
                            chapterNumber = match[1];
                        } else {
                            // Fallback to existing patterns
                            const pattern1 = /(chapter|chp|ch|chap|issue|iss|is|volume|vol|v|episode|ep|eps|part|pt)[\\s:]*([\\d\\.]+)/i;
                            let match1 = text.match(pattern1);
                            if (match1 && match[2]) {
                                chapterNumber = match1[2];
                            }
                            
                            if (!chapterNumber) {
                                const pattern2 = /#\\s*([\\d\\.]+)/i;
                                let match2 = text.match(pattern2);
                                if (match2 && match2[1]) {
                                    chapterNumber = match2[1];
                                }
                            }
                            
                            if (!chapterNumber) {
                                const numberMatch = text.match(/\\b(\\d+(?:\\.\\d+)?)\\b/);
                                if (numberMatch) {
                                    chapterNumber = numberMatch[1];
                                }
                            }
                        }
                        
                        // Extract date from time element
                            let uploadDate = null;
                            const timeElement = container.querySelector('time[datetime]');
                            if (timeElement) {
                                const datetime = timeElement.getAttribute('datetime');
                                if (datetime) {
                                    uploadDate = datetime;
                                } else {
                                    uploadDate = timeElement.textContent.trim();
                                }
                            }
                            
                            // NEW: Check for relative time patterns in the text
                            if (!uploadDate) {
                                const relativeTime = extractRelativeTime(text);
                                if (relativeTime) {
                                    const calculatedDate = calculateDateFromRelativeTime(relativeTime);
                                    if (calculatedDate) {
                                        uploadDate = calculatedDate;
                                    }
                                }
                            }
                            
                            // If no date found, use existing date detection methods
                            if (!uploadDate) {
                                for (const pattern of datePatterns) {
                                    const dateMatch = text.match(pattern);
                                    if (dateMatch) {
                                        uploadDate = dateMatch[0];
                                        break;
                                    }
                                }
                            }
                        
                        if (!uploadDate) {
                            uploadDate = findDateInTableMap(link, tableDateMap);
                        }
                        
                        if (!uploadDate) {
                            uploadDate = findDateInNearbyElements(link);
                        }
                        
                       // Clean the title by removing dates if they were accidentally included
                           let finalTitle = cleanTitle;
                           if (uploadDate && finalTitle.includes(uploadDate)) {
                               finalTitle = finalTitle.replace(uploadDate, '').trim();
                               finalTitle = finalTitle.replace(/^[\\s\\.,;:-]+|[\\s\\.,;:-]+$/g, '').trim();
                           }
                           
                           // NEW: Remove time patterns from final title
                           for (const timePattern of timePatterns) {
                               finalTitle = finalTitle.replace(timePattern, '').trim();
                           }
                           finalTitle = finalTitle.replace(/^[\\s\\.,;:-]+|[\\s\\.,;:-]+$/g, '').trim();
                        
                        if (chapterNumber) {
                            const chapterData = {
                                "url": href,
                                "title": finalTitle || text
                            };
                            
                            if (uploadDate) {
                                chapterData["upload_date"] = uploadDate;
                            }
                            
                            chapterLinks[chapterNumber] = chapterData;
                        } else {
                            // Check if this might be a title-only chapter
                            if (!/\\d/.test(text) && text.length > 3) {
                                potentialTitleOnlyLinks.push({
                                    text: text,
                                    href: href,
                                    link: link
                                });
                            }
                        }
                    }
                }
            }
            
            // If we didn't find the specific structure, use the general approach
            if (!foundSpecificStructure) {
                for (let link of links) {
                    const text = (link.textContent || link.innerText || '').trim();
                    const href = link.href;
                    
                    if (!text || !href) continue;
                    
                    // Skip titles with numbers in parentheses (e.g., "Iron Man (2016)")
                    if (excludePattern.test(text)) {
                        continue;
                    }
                    
                    // Check if text contains special chapter identifiers
                    let hasSpecialChapterIdentifier = false;
                    for (const pattern of specialChapterPatterns) {
                        if (pattern.test(text)) {
                            hasSpecialChapterIdentifier = true;
                            break;
                        }
                    }
                    
                    // Filter out links from different manga series
                    if (currentMangaId) {
                        let isSameSeries = false;
                        
                        // Check if link href contains the current manga ID
                        if (href.includes(currentMangaId)) {
                            isSameSeries = true;
                        }
                        
                        // Additional checks for common URL patterns
                        if (!isSameSeries) {
                            // Check for similar URL structure
                            const linkUrlObj = new URL(href);
                            const currentUrlObj = new URL(currentUrl);
                            
                            // Same domain and similar path structure
                            if (linkUrlObj.hostname === currentUrlObj.hostname) {
                                const linkPathParts = linkUrlObj.pathname.split('/').filter(part => part.length > 2);
                                const currentPathParts = currentUrlObj.pathname.split('/').filter(part => part.length > 2);
                                
                                if (linkPathParts.length > 0 && currentPathParts.length > 0) {
                                    // Check if last path segment is similar (common for chapter pages)
                                    const lastLinkPart = linkPathParts[linkPathParts.length - 1];
                                    const lastCurrentPart = currentPathParts[currentPathParts.length - 1];
                                    
                                    if (lastLinkPart && lastCurrentPart) {
                                        // Check for common prefixes or patterns
                                        const linkBase = lastLinkPart.replace(/[^a-z]/gi, '');
                                        const currentBase = lastCurrentPart.replace(/[^a-z]/gi, '');
                                        
                                        if (linkBase.length > 3 && currentBase.length > 3 &&
                                            (linkBase.includes(currentBase) || currentBase.includes(linkBase))) {
                                            isSameSeries = true;
                                        }
                                    }
                                }
                            }
                        }
                        
                        if (!isSameSeries) {
                            continue; // Skip links from different series
                        }
                    }
                    
                    // Try to extract chapter number with various patterns
                    let chapterNumber = null;
                    let cleanTitle = text; // Start with original text
                    
                    // Pattern 1: Chapter X, Issue X, Volume X, etc.
                    const pattern1 = /(chapter|chp|ch|chap|issue|iss|is|volume|vol|v|episode|ep|eps|part|pt)[\\s:]*([\\d\\.]+)/i;
                    let match1 = text.match(pattern1);
                    if (match1 && match1[2]) {
                        chapterNumber = match1[2];
                        // Don't modify the title - keep the full original text
                    }
                    
                    // Pattern 2: #X, #01, #001, etc.
                    if (!chapterNumber) {
                        const pattern2 = /#\\s*([\\d\\.]+)/i;
                        let match2 = text.match(pattern2);
                        if (match2 && match2[1]) {
                            chapterNumber = match2[1];
                            // Don't modify the title - keep the full original text
                        }
                    }
                    
                    // Pattern 3: Number at beginning or end (standalone numbers)
                    if (!chapterNumber) {
                        const pattern3 = /^\\s*([\\d\\.]+)\\s*$|\\b([\\d\\.]+)\\s*(?:chapter|chp|ch|chap|issue|iss|is|volume|vol|v|episode|ep|eps|part|pt)\\b/i;
                        let match3 = text.match(pattern3);
                        if (match3 && (match3[1] || match3[2])) {
                            chapterNumber = match3[1] || match3[2];
                            // Don't modify the title - keep the full original text
                        }
                    }
                    
                    // Pattern 4: Look for numbers in the text (fallback)
                    if (!chapterNumber) {
                        const numberMatch = text.match(/\\b(\\d+(?:\\.\\d+)?)\\b/);
                        if (numberMatch) {
                            chapterNumber = numberMatch[1];
                            // Don't modify the title - keep the full original text
                        }
                    }
                    
                    // Pattern 5: Special chapter identifiers (assign special numbers)
                    if (!chapterNumber) {
                        // Enhanced detection for complex patterns like "Batman '66 [II] TPB 5 (Part 2)"
                        let tpbNumber = null;
                        let partNumber = null;
                        let hasSpecialIdentifier = false;
                        
                        // More robust TPB detection that handles various formats
                        const tpbPatterns = [
                            /TPB[\\s\\-]*(\\d+)/i,        // TPB 1, TPB-1, TPB1
                        ];
                        
                        // Try all TPB patterns
                        for (const pattern of tpbPatterns) {
                            const match = text.match(pattern);
                            if (match && match[1]) {
                                tpbNumber = parseInt(match[1]);
                                hasSpecialIdentifier = true;
                                break;
                            }
                        }
                        
                        // Part number detection
                        const partPatterns = [
                            /\\(Part[\\s\\-]*(\\d+)\\)/i,    // (Part 1)
                            /\\(Pt\\.?[\\s\\-]*(\\d+)\\)/i,  // (Pt. 1), (Pt 1)
                            /Part[\\s\\-]*(\\d+)/i,          // Part 1 (without parentheses)
                            /Pt\\.?[\\s\\-]*(\\d+)/i         // Pt. 1, Pt 1 (without parentheses)
                        ];
                        
                        for (const pattern of partPatterns) {
                            const match = text.match(pattern);
                            if (match && match[1]) {
                                partNumber = parseInt(match[1]);
                                hasSpecialIdentifier = true;
                                break;
                            }
                        }
                        
                        // Also check for other special identifiers as fallback
                        if (!hasSpecialIdentifier) {
                            for (const pattern of specialChapterPatterns) {
                                if (pattern.test(text)) {
                                    hasSpecialIdentifier = true;
                                    break;
                                }
                            }
                        }
                        
                        if (hasSpecialIdentifier) {
                            // Handle the Batman '66 series and similar patterns
                            if (tpbNumber !== null && partNumber !== null) {
                                // Both TPB number and part number exist
                                // Calculate sequential numbering: TPB1 Part1=1, TPB1 Part2=2, TPB2 Part1=3, etc.
                                chapterNumber = ((tpbNumber - 1) * 2 + partNumber).toString();
                            } else if (tpbNumber !== null) {
                                // Only TPB number exists
                                chapterNumber = (900 + tpbNumber).toString(); // TPB1=901, TPB2=902, etc.
                            } else if (partNumber !== null) {
                                // Only part number exists
                                chapterNumber = (800 + partNumber).toString(); // Part1=801, Part2=802, etc.
                            } else {
                                // Other special types
                                if (/Full/i.test(text)) {
                                    chapterNumber = "701";
                                } else if (/Omnibus/i.test(text)) {
                                    chapterNumber = "702";
                                } else if (/Special/i.test(text)) {
                                    chapterNumber = "703";
                                } else if (/One[\\-\\s]?Shot/i.test(text)) {
                                    chapterNumber = "704";
                                } else if (/Extra/i.test(text)) {
                                    chapterNumber = "705";
                                } else if (/Bonus/i.test(text)) {
                                    chapterNumber = "706";
                                } else if (/TPB/i.test(text)) {
                                    chapterNumber = "707"; // TPB without number
                                } else {
                                    chapterNumber = "799";
                                }
                            }
                        }
                    }
                    
                    // NEW: Check if this might be a title-only chapter (no numbers found)
                    if (!chapterNumber) {
                        // Check if the URL structure suggests it's a chapter link
                        // For readcomiconline.li pattern: /Comic/Series-Name/Chapter-Title?id=number#page
                        const comicUrlPattern = /\\/Comic\\/[^\\/]+\\/[^\\/]+(?:\\?id=\\d+)?(?:#\\d+)?$/i;
                        
                        // Check if href follows the chapter URL pattern but text has no numbers
                        if (comicUrlPattern.test(href) &&
                            !/\\d/.test(text) && // No digits in text
                            text.length > 3 && // Reasonable length for a title
                            !hasSpecialChapterIdentifier) { // Not a special chapter
                            
                            // Store for later processing
                            potentialTitleOnlyLinks.push({
                                text: text,
                                href: href,
                                link: link
                            });
                            continue; // Skip normal processing for now
                        }
                    }
                    
                    if (chapterNumber) {
                        // Extract upload date (but don't remove from title)
                        let uploadDate = null;

                        // Check in the original text for dates (but don't modify title)
                        for (const pattern of datePatterns) {
                            const dateMatch = text.match(pattern);
                            if (dateMatch) {
                                uploadDate = dateMatch[0];
                                break;
                            }
                        }

                        // NEW: Check for relative time patterns in the text
                        if (!uploadDate) {
                            const relativeTime = extractRelativeTime(text);
                            if (relativeTime) {
                                const calculatedDate = calculateDateFromRelativeTime(relativeTime);
                                if (calculatedDate) {
                                    uploadDate = calculatedDate;
                                }
                            }
                        }

                        // If no date found, check table date map using link text or href
                        if (!uploadDate) {
                            uploadDate = findDateInTableMap(link, tableDateMap);
                        }
                        
                        // If still no date found, check nearby elements
                        if (!uploadDate) {
                            uploadDate = findDateInNearbyElements(link);
                        }
                        
                        // Clean the title by removing dates if they were accidentally included
                        let finalTitle = cleanTitle;
                        if (uploadDate && finalTitle.includes(uploadDate)) {
                            finalTitle = finalTitle.replace(uploadDate, '').trim();
                            // Clean up any leftover punctuation
                            finalTitle = finalTitle.replace(/^[\\s\\.,;:-]+|[\\s\\.,;:-]+$/g, '').trim();
                        }

                        // NEW: Remove time patterns from final title
                        for (const timePattern of timePatterns) {
                            finalTitle = finalTitle.replace(timePattern, '').trim();
                        }
                        finalTitle = finalTitle.replace(/^[\\s\\.,;:-]+|[\\s\\.,;:-]+$/g, '').trim();

                        const chapterData = {
                            "url": href,
                            "title": finalTitle || text // Use the cleaned title or original
                        };
                        
                        if (uploadDate) {
                            chapterData["upload_date"] = uploadDate;
                        }
                        
                        // NEW: Add special chapter type identifier
                        if (hasSpecialChapterIdentifier) {
                            let chapterType = "normal";
                            
                            if (/(Part|Pt\\.)\\s*\\d+/i.test(text)) {
                                chapterType = "part";
                            } else if (/Full/i.test(text)) {
                                chapterType = "full";
                            } else if (/TPB/i.test(text)) {
                                chapterType = "tpb";
                            } else if (/Omnibus/i.test(text)) {
                                chapterType = "omnibus";
                            } else if (/Special/i.test(text)) {
                                chapterType = "special";
                            } else if (/One[\\-\\s]?Shot/i.test(text)) {
                                chapterType = "oneshot";
                            } else if (/Extra/i.test(text)) {
                                chapterType = "extra";
                            } else if (/Bonus/i.test(text)) {
                                chapterType = "bonus";
                            }
                            
                            chapterData["chapter_type"] = chapterType;
                        }
                        
                        chapterLinks[chapterNumber] = chapterData;
                    }
                }
            }
            
            // NEW: Process title-only chapters
            if (potentialTitleOnlyLinks.length > 0) {
                // Use alphabetical ordering for title-only chapters
                potentialTitleOnlyLinks.sort((a, b) => a.text.localeCompare(b.text));
                
                let titleChapterCounter = 0.01; // Start at 0.01 to avoid conflicts with numbered chapters
                
                for (const titleLink of potentialTitleOnlyLinks) {
                    const chapterNumber = titleChapterCounter.toString();
                    titleChapterCounter++;
                    
                    // Extract upload date
                    let uploadDate = null;

                    // Check in the original text for dates (but don't modify title)
                    for (const pattern of datePatterns) {
                        const dateMatch = titleLink.text.match(pattern);
                        if (dateMatch) {
                            uploadDate = dateMatch[0];
                            break;
                        }
                    }

                    // NEW: Check for relative time patterns in the text
                    if (!uploadDate) {
                        const relativeTime = extractRelativeTime(titleLink.text);
                        if (relativeTime) {
                            const calculatedDate = calculateDateFromRelativeTime(relativeTime);
                            if (calculatedDate) {
                                uploadDate = calculatedDate;
                            }
                        }
                    }

                    // If no date found, check table date map using link text or href
                    if (!uploadDate) {
                        uploadDate = findDateInTableMap(titleLink.link, tableDateMap);
                    }
                    
                    // If still no date found, check nearby elements
                    if (!uploadDate) {
                        uploadDate = findDateInNearbyElements(titleLink.link);
                    }
                    
                    // Clean the title by removing dates if they were accidentally included
                    let finalTitle = titleLink.text;
                    if (uploadDate && finalTitle.includes(uploadDate)) {
                        finalTitle = finalTitle.replace(uploadDate, '').trim();
                        // Clean up any leftover punctuation
                        finalTitle = finalTitle.replace(/^[\\s\\.,;:-]+|[\\s\\.,;:-]+$/g, '').trim();
                    }

                    // NEW: Remove time patterns from final title
                    for (const timePattern of timePatterns) {
                        finalTitle = finalTitle.replace(timePattern, '').trim();
                    }
                    finalTitle = finalTitle.replace(/^[\\s\\.,;:-]+|[\\s\\.,;:-]+$/g, '').trim();

                    const chapterData = {
                        "url": titleLink.href,
                        "title": finalTitle || titleLink.text,
                        "chapter_type": "title_only"
                    };
                    
                    if (uploadDate) {
                        chapterData["upload_date"] = uploadDate;
                    }
                    
                    chapterLinks[chapterNumber] = chapterData;
                }
            }
            
            function findDatesInTables() {
                const dateMap = new Map();
                const tables = document.querySelectorAll('table');
                
                for (let table of tables) {
                    const rows = table.querySelectorAll('tr');
                    for (let row of rows) {
                        const cells = row.querySelectorAll('td, th');
                        if (cells.length >= 2) {
                            const leftCell = cells[0];
                            const rightCell = cells[1];
                            
                            // Check if right cell contains a date
                            const rightText = (rightCell.textContent || '').trim();
                            let foundDate = null;
                            
                            for (const pattern of datePatterns) {
                                const dateMatch = rightText.match(pattern);
                                if (dateMatch) {
                                    foundDate = dateMatch[0];
                                    break;
                                }
                            }
                            
                            if (foundDate) {
                                // Check left cell for chapter link or text
                                const leftLinks = leftCell.querySelectorAll('a');
                                if (leftLinks.length > 0) {
                                    for (let link of leftLinks) {
                                        const linkText = (link.textContent || '').trim();
                                        const linkHref = link.href;
                                        if (linkText) {
                                            dateMap.set(linkText, foundDate);
                                            dateMap.set(linkHref, foundDate);
                                        }
                                    }
                                } else {
                                    const leftText = (leftCell.textContent || '').trim();
                                    if (leftText) {
                                        dateMap.set(leftText, foundDate);
                                    }
                                }
                            }
                        }
                    }
                }
                return dateMap;
            }
            
            function findDateInTableMap(link, tableDateMap) {
                const linkText = (link.textContent || '').trim();
                const linkHref = link.href;
                
                // Try exact matches first
                if (tableDateMap.has(linkText)) {
                    return tableDateMap.get(linkText);
                }
                if (tableDateMap.has(linkHref)) {
                    return tableDateMap.get(linkHref);
                }
                
                // Try partial matches for link text
                for (let [key, value] of tableDateMap.entries()) {
                    if (linkText.includes(key) || key.includes(linkText)) {
                        return value;
                    }
                }
                
                return null;
            }
            
            function findDateInNearbyElements(element) {
                // Check parent
                if (element.parentElement) {
                    const parentText = element.parentElement.textContent;
                    for (const pattern of datePatterns) {
                        const match = parentText.match(pattern);
                        if (match) return match[0];
                    }
                }
                
                // Check siblings
                let sibling = element.previousElementSibling;
                while (sibling) {
                    const siblingText = sibling.textContent;
                    for (const pattern of datePatterns) {
                        const match = siblingText.match(pattern);
                        if (match) return match[0];
                    }
                    sibling = sibling.previousElementSibling;
                }
                
                sibling = element.nextElementSibling;
                while (sibling) {
                    const siblingText = sibling.textContent;
                    for (const pattern of datePatterns) {
                        const match = siblingText.match(pattern);
                        if (match) return match[0];
                    }
                    sibling = sibling.nextElementSibling;
                }
                
                // Check parent's siblings (for table-like structures)
                if (element.parentElement) {
                    const parentSibling = element.parentElement.previousElementSibling;
                    if (parentSibling) {
                        const parentSiblingText = parentSibling.textContent;
                        for (const pattern of datePatterns) {
                            const match = parentSiblingText.match(pattern);
                            if (match) return match[0];
                        }
                    }
                    
                    const nextParentSibling = element.parentElement.nextElementSibling;
                    if (nextParentSibling) {
                        const nextParentSiblingText = nextParentSibling.textContent;
                        for (const pattern of datePatterns) {
                            const match = nextParentSiblingText.match(pattern);
                            if (match) return match[0];
                        }
                    }
                }
                
                return null;
            }
            
            return Object.keys(chapterLinks).length > 0 ? chapterLinks : null;
        })();
        """
    }
}
