require "commonmarker"

module ApplicationHelper
  def markdown_to_html(text)
    return "" if text.blank?

    Commonmarker.to_html(text).html_safe
  end
end
