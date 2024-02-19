chrome.tabs.onUpdated.addListener(function(tabId, changeInfo, tab) {
  if (changeInfo.status === 'complete' && tab.active) {
    writeURLToFile(tab.url);
  }
});

function writeURLToFile(url) {
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
