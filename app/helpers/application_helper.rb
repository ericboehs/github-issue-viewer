require "commonmarker"

module ApplicationHelper
  def markdown_to_html(text)
    return "" if text.blank?

    # Parse with GFM and syntax highlighting, allowing raw HTML like GitHub
    options = {
      parse: {
        smart: true
      },
      render: {
        unsafe: true, # Allow raw HTML like GitHub does
        github_pre_lang: true # Add language class to code blocks
      }
    }

    Commonmarker.to_html(text, options: options).html_safe
  end
end
