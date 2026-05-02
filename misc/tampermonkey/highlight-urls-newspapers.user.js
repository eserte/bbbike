// ==UserScript==
// @name         URL-Links hervorheben mit Set (Berliner Zeitungen, Debugging)
// @namespace    http://tampermonkey.net/
// @version      1.7
// @description  Hebt Links hervor, deren href in externer URL-Liste steht; mit Debug-Logs; nur auf tagesspiegel.de und anderen Berliner Zeitungen
// @author       Dein Name
// @match        https://*.tagesspiegel.de/*
// @match        https://*.morgenpost.de/*
// @match        https://*.berliner-zeitung.de/*
// @match        https://*.nd-aktuell.de/*
// @match        https://entwicklungsstadt.de/*
// @match        https://*.entwicklungsstadt.de/*
// @grant        GM_getValue
// @grant        GM_setValue
// @grant        GM_registerMenuCommand
// @grant        GM.xmlHttpRequest
// @connect      *
// @downloadURL  http://raw.githubusercontent.com/eserte/bbbike/refs/heads/master/misc/tampermonkey/highlight-urls-newspapers.user.js
// ==/UserScript==

const DEFAULT_URL_LIST_FILE = 'https://example.com/tampermonkey/newspaper_urls.json';
let urlListFile = GM_getValue('urlListFile', DEFAULT_URL_LIST_FILE);

GM_registerMenuCommand('Set urlListFile', () => {
    const value = prompt('urlListFile:', urlListFile);
    if (value !== null && value.trim() !== '') {
        urlListFile = value.trim();
        GM_setValue('urlListFile', urlListFile);
    }
});

(function() {
    'use strict';

    // Nur ausführen, wenn wir im Hauptframe sind
    if (window.top !== window.self) {
        return; // Skript nicht im iframe ausführen
    }

    function normalizeUrl(url) {
        try {
            const u = new URL(url);
            let pathname = u.pathname;
            if (pathname.length > 1 && pathname.endsWith('/')) {
                pathname = pathname.slice(0, -1);
            }
            //return `${u.protocol}//${u.host}${pathname}${u.search}${u.hash}`;
            return `${u.protocol}//${u.host}${pathname}`;
        } catch (e) {
            console.warn('normalizeUrl: ungültige URL:', url);
            return url;
        }
    }

    async function fetchUrlList() {
        const response = await GM.xmlHttpRequest({
            method: 'GET',
            url: urlListFile
        });
    
	if (response.status < 200 || response.status >= 300) {
            throw new Error(`Fehler beim Laden der URL-Liste: ${response.status} ${response.statusText}`);
        }
    
        return JSON.parse(response.responseText);
    }

    let cachedUrlSet = null;

    function highlightLinks() {
        if (!cachedUrlSet) {
            console.warn('[DEBUG] highlightLinks: cachedUrlSet ist noch nicht geladen.');
            return;
        }

        const links = document.querySelectorAll('a[href]:not([data-highlighted])');
        if (links.length === 0) return;

        console.log('[DEBUG] Anzahl neu zu prüfender <a>-Links auf der Seite:', links.length);

        let countMatched = 0;

        links.forEach(link => {
            link.setAttribute('data-highlighted', 'true');
            const normHref = normalizeUrl(link.href);
            if (cachedUrlSet.has(normHref)) {
                countMatched++;
                link.style.border = '4px solid green';
                link.style.padding = '2px';

                // Optional: Ausgabe der hervorgehobenen URL
                console.log('[DEBUG] Hervorgehobener Link:', normHref);
            }
        });

        if (countMatched > 0) {
            console.log('[DEBUG] Anzahl neu hervorgehobener Links auf der Seite:', countMatched);
        }
    }

    fetchUrlList()
        .then(urlArray => {
            console.log('[DEBUG] Anzahl geladener URLs aus JSON:', urlArray.length);
            const normalizedUrls = urlArray.map(normalizeUrl);
            cachedUrlSet = new Set(normalizedUrls);

            highlightLinks();

            // Beobachte die Seite auf dynamisch hinzugefügte Inhalte
            const observer = new MutationObserver((mutations) => {
                let hasAddedNodes = false;
                for (const mutation of mutations) {
                    if (mutation.addedNodes.length > 0) {
                        hasAddedNodes = true;
                        break;
                    }
                }
                if (hasAddedNodes) {
                    highlightLinks();
                }
            });

            observer.observe(document.body, {
                childList: true,
                subtree: true
            });
        })
        .catch(error => {
            console.error('[DEBUG] Highlight-Skript Fehler:', error);
        });

})();
