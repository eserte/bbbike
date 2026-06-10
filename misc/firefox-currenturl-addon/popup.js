document.addEventListener('DOMContentLoaded', function() {
  const checkbox = document.getElementById('enabled-checkbox');

  // Load initial state
  chrome.storage.local.get({ enabled: true }, function(items) {
    checkbox.checked = items.enabled;
  });

  // Save changes
  checkbox.addEventListener('change', function() {
    chrome.storage.local.set({ enabled: checkbox.checked });
  });
});
