// ==UserScript==
// @name         URL-Links hervorheben mit Set (BVV, Debugging)
// @namespace    http://tampermonkey.net/
// @version      1.6
// @description  Hebt Links hervor, deren href in externer URL-Liste steht; mit Debug-Logs; nur auf BVV-Seiten
// @author       Dein Name
// @match        https://bvv-charlottenburg-wilmersdorf.berlin.de/pi-r/*
// @match        https://bvv-friedrichshain-kreuzberg.berlin.de/pi-r/*
// @match        https://bvv-lichtenberg.berlin.de/pi-r/*
// @match        https://bvv-mitte.berlin.de/pi-r/*
// @match        https://bvv-marzahn-hellersdorf.berlin.de/pi-r/*
// @match        https://bvv-neukoelln.berlin.de/pi-r/*
// @match        https://bvv-pankow.berlin.de/pi-r/*
// @match        https://bvv-reinickendorf.berlin.de/pi-r/*
// @match        https://bvv-spandau.berlin.de/pi-r/*
// @match        https://bvv-steglitz-zehlendorf.berlin.de/pi-r/*
// @match        https://bvv-tempelhof-schoeneberg.berlin.de/pi-r/*
// @match        https://bvv-treptow-koepenick.berlin.de/pi-r/*
// @grant        GM_getValue
// @grant        GM_setValue
// @grant        GM_registerMenuCommand
// @grant        GM.xmlHttpRequest
// @connect      *
// @downloadURL  http://raw.githubusercontent.com/eserte/bbbike/refs/heads/master/misc/tampermonkey/highlight-urls-bvv.user.js
// ==/UserScript==

const DEFAULT_URL_LIST_FILE = 'https://example.com/tampermonkey/bvv_urls.json';
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
            return `${u.protocol}//${u.host}${pathname}${u.search}${u.hash}`;
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

    function highlightLinks(urlArray) {
        console.log('[DEBUG] Anzahl geladener URLs aus JSON:', urlArray.length);

        const normalizedUrls = urlArray.map(normalizeUrl);
        const urlSet = new Set(normalizedUrls);

        const links = document.querySelectorAll('a[href]');
        console.log('[DEBUG] Anzahl gefundener <a>-Links auf der Seite:', links.length);

        let countMatched = 0;

        links.forEach(link => {
            const normHref = normalizeUrl(link.href);
            if (urlSet.has(normHref)) {
                countMatched++;
                link.style.border = '4px solid green';
                link.style.padding = '2px';

                // Optional: Ausgabe der hervorgehobenen URL
                console.log('[DEBUG] Hervorgehobener Link:', normHref);
            }
        });

        console.log('[DEBUG] Anzahl hervorgehobener Links auf der Seite:', countMatched);
    }

    fetchUrlList()
        .then(urlArray => {
            highlightLinks(urlArray);
        })
        .catch(error => {
            console.error('[DEBUG] Highlight-Skript Fehler:', error);
        });

})();
