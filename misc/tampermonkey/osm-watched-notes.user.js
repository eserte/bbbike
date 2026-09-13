// ==UserScript==
// @name         OSM Watched Notes
// @namespace    https://www.openstreetmap.org/
// @version      0.1
// @description  Show selected OSM notes in blue on the map
// @match        https://www.openstreetmap.org/*
// @grant        GM_getValue
// @grant        GM_setValue
// @grant        GM_registerMenuCommand
// @grant        GM_xmlhttpRequest
// @grant        unsafeWindow
// @connect      *
// @run-at       document-start
// @downloadURL  http://raw.githubusercontent.com/eserte/bbbike/refs/heads/master/misc/tampermonkey/osm-watched-notes.user.js
// ==/UserScript==

// To generate the list of watched OSM notes, use something like
//
//     perl -nle '/^note\s+(\d+)/ and print $1' ~/src/bbbike/tmp/osm_watch_list | sort >| osm_note_watches.txt
//
// move the resulting file to a accessible webserver, and configure
// noteIdURL of this tampermonkey script to point to the URL this file.

const DEFAULT_NOTE_ID_URL = 'https://example.com/tampermonkey/osm_note_watches.txt';
let noteIdURL = GM_getValue('noteIdURL', DEFAULT_NOTE_ID_URL);

GM_registerMenuCommand('Set noteIdURL', () => {
    const value = prompt('noteIdURL:', noteIdURL);
    if (value !== null && value.trim() !== '') {
        noteIdURL = value.trim();
        GM_setValue('noteIdURL', noteIdURL);
    }
});

(function () {
'use strict';

/*
 * URL of a text file containing one OSM note ID per line.
 *
 * Change this to your actual URL.
 */

let watchedNotes = new Set();
let notesLayerHooked = false;

/*
 * Fetch the watched-note list.
 *
 * Lines may contain whitespace or comments beginning with '#'.
 */
function loadWatchedNotes() {
    GM_xmlhttpRequest({
        method: 'GET',
        url: noteIdURL,
        nocache: true,

        onload: function (response) {
            if (response.status < 200 || response.status >= 300) {
                console.error(
                    '[OSM watched notes] HTTP error:',
                    response.status,
                    response.statusText
                );
                return;
            }

            const ids = new Set();

            for (const line of response.responseText.split(/\r?\n/)) {
                const id = line.replace(/#.*/, '').trim();

                if (/^\d+$/.test(id)) {
                    ids.add(Number(id));
                }
            }

            watchedNotes = ids;

            console.log(
                '[OSM watched notes] loaded',
                watchedNotes.size,
                'note IDs'
            );

            /*
             * The map may already exist by the time the list
             * has finished loading.
             */
            recolorExistingNotes();
        },

        onerror: function (error) {
            console.error(
                '[OSM watched notes] could not load note list',
                error
            );
        }
    });
}

/*
 * Change the color of an existing OSM note marker to blue.
 *
 * OSM uses an SVG <use> element whose "color" attribute contains
 * the CSS variable for the marker color.
 */
function recolorMarker(marker) {
    if (!marker || !watchedNotes.has(Number(marker.id))) {
        return;
    }

    if (!marker._icon) {
        return;
    }

    for (const element of marker._icon.querySelectorAll('use')) {
        if (element.hasAttribute('color')) {
            element.setAttribute('color', 'var(--marker-blue)');
        }
    }

    marker._icon.classList.add('osm-watched-note');
}

/*
 * Install a small hook on a marker so that if OSM changes its
 * icon later (for example because the note status changes),
 * we recolor it again.
 */
function watchMarker(marker) {
    if (!marker || marker._osmWatchedHook) {
        return;
    }

    marker._osmWatchedHook = true;

    const originalSetIcon = marker.setIcon;

    marker.setIcon = function (icon, ...args) {
        const result = originalSetIcon.call(this, icon, ...args);
        recolorMarker(this);
        return result;
    };

    recolorMarker(marker);
}

function recolorExistingNotes() {
    if (!watchedNotes.size) {
        return;
    }

    const layer = getNotesLayer();

    if (!layer) {
        return;
    }

    layer.eachLayer(function (marker) {
        watchMarker(marker);
    });
}

function getNotesLayer() {
    /*
     * initializeNotesLayer() receives the actual map object.
     * We save it here when that function is called.
     */
    return unsafeWindow.__osmWatchedNotesLayer || null;
}

/*
 * Hook the OSM note-layer initialization.
 *
 * index.js currently does:
 *
 *     OSM.initializeNotesLayer(map);
 *
 * after creating the map and its noteLayer.
 */
function hookOSM() {
    if (!unsafeWindow.OSM ||
        typeof OSM.initializeNotesLayer !== 'function' ||
        notesLayerHooked) {
        return;
    }

    const originalInitializeNotesLayer = OSM.initializeNotesLayer;

    OSM.initializeNotesLayer = function (map) {
        unsafeWindow.__osmWatchedNotesLayer = map.noteLayer;

        const result = originalInitializeNotesLayer.apply(this, arguments);

        map.noteLayer.on('layeradd', function (event) {
            watchMarker(event.layer);
        });

        /*
         * The list might have loaded before the map was initialized.
         */
        recolorExistingNotes();

        return result;
    };

    notesLayerHooked = true;
}

/*
 * At document-start OSM may not exist yet. Poll briefly until
 * its JavaScript has been loaded.
 */
function waitForOSM() {
    hookOSM();

    if (!notesLayerHooked) {
        setTimeout(waitForOSM, 10);
    }
}

loadWatchedNotes();
waitForOSM();

})();
