module TopUsersHelper
  def top_users_tab_classes(active)
    classes = ["crayons-tabs__item"]
    classes << "crayons-tabs__item--current" if active
    classes.join(" ")
  end
end
