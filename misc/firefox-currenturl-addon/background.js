let enabled = true;
let lastURL = null;

// Initialize enabled state from storage
chrome.storage.local.get({ enabled: true }, function(items) {
  enabled = items.enabled;
  updateIcon();
});

// Listen for changes in storage
chrome.storage.onChanged.addListener(function(changes, area) {
  if (area === 'local' && changes.enabled) {
    enabled = changes.enabled.newValue;
    updateIcon();
  }
});

chrome.tabs.onUpdated.addListener(function(tabId, changeInfo, tab) {
  if (changeInfo.status === 'complete' && tab.active) {
    writeURLToFile(tab.url);
  }
});

chrome.tabs.onActivated.addListener(function(activeInfo) {
  chrome.tabs.get(activeInfo.tabId, function(tab) {
    if (tab && tab.url) {
      writeURLToFile(tab.url);
    }
  });
});

function updateIcon() {
  const iconPath = enabled ? "icon.png" : "icon-disabled.png";
  chrome.browserAction.setIcon({ path: iconPath });
}

function writeURLToFile(url) {
  if (!enabled) {
    return;
  }
  if (url === lastURL) {
    return;
  }
  // Ignore internal firefox pages
  if (url.startsWith('about:') || url.startsWith('chrome:')) {
    return;
  }

  lastURL = url;

  // Create a blob with the URL content
  var blob = new Blob([url], {type: 'text/plain'});
  
  // Create a URL object
  var urlObject = URL.createObjectURL(blob);
  
  // Use the Downloads API to download the URL file
  chrome.downloads.download({
    url: urlObject,
    filename: 'current_url.txt',
//    conflictAction: 'uniquify',
    conflictAction: 'overwrite',
    saveAs: false
  });
}
