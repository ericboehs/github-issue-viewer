require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "application helper module exists" do
    assert_kind_of Module, ApplicationHelper
  end

  test "application helper can be included" do
    assert_includes self.class.ancestors, ApplicationHelper
  end
end
