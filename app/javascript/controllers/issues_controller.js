import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="issues"
export default class extends Controller {
  connect() {
    this.setupLoadingStates()
  }

  setupLoadingStates() {
    // Listen for Turbo Frame load events
    document.addEventListener('turbo:frame-load', this.handleFrameLoad.bind(this))
    document.addEventListener('turbo:before-frame-render', this.handleBeforeFrameRender.bind(this))
  }

  showLoadingState() {
    const resultsFrame = document.getElementById('issues-content')
    if (resultsFrame) {
      resultsFrame.innerHTML = this.loadingHTML()
    }
  }

  handleBeforeFrameRender(event) {
    if (event.target.id === 'issues-content') {
      this.showLoadingState()
    }
  }

  handleFrameLoad(event) {
    if (event.target.id === 'issues-content') {
      this.hideLoadingState()
    }
  }

  hideLoadingState() {
    // Loading state is automatically replaced by the new content
    // This method can be used for cleanup if needed
  }

  loadingHTML() {
    return `
      <div class="bg-white dark:bg-gray-800 border-b dark:border-gray-700 p-8">
        <div class="flex items-center justify-center space-x-3">
          <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
          <span class="text-gray-600 dark:text-gray-400 text-lg">Loading issues...</span>
        </div>
        <div class="mt-6 bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
          <!-- Loading skeleton -->
          <div class="animate-pulse p-4">
            <div class="flex space-x-3">
              <div class="w-4 h-4 bg-gray-300 dark:bg-gray-600 rounded-full"></div>
              <div class="flex-1 space-y-2">
                <div class="h-4 bg-gray-300 dark:bg-gray-600 rounded w-3/4"></div>
                <div class="h-3 bg-gray-300 dark:bg-gray-600 rounded w-1/2"></div>
              </div>
            </div>
          </div>
          <div class="animate-pulse p-4">
            <div class="flex space-x-3">
              <div class="w-4 h-4 bg-gray-300 dark:bg-gray-600 rounded-full"></div>
              <div class="flex-1 space-y-2">
                <div class="h-4 bg-gray-300 dark:bg-gray-600 rounded w-2/3"></div>
                <div class="h-3 bg-gray-300 dark:bg-gray-600 rounded w-1/3"></div>
              </div>
            </div>
          </div>
          <div class="animate-pulse p-4">
            <div class="flex space-x-3">
              <div class="w-4 h-4 bg-gray-300 dark:bg-gray-600 rounded-full"></div>
              <div class="flex-1 space-y-2">
                <div class="h-4 bg-gray-300 dark:bg-gray-600 rounded w-4/5"></div>
                <div class="h-3 bg-gray-300 dark:bg-gray-600 rounded w-2/5"></div>
              </div>
            </div>
          </div>
        </div>
      </div>
    `
  }
}
