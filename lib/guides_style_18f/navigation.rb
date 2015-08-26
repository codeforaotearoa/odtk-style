# @author Mike Bland (michael.bland@gsa.gov)

require 'safe_yaml'

module GuidesStyle18F
  # Automatically updates the `navigation:` field in _config.yml.
  #
  # Does this by parsing the front matter from files in `pages/`. Preserves the
  # existing order of items in `navigation:`, but new items may need to be
  # reordered manually.
  def self.update_navigation_configuration(basedir)
    config_path = File.join basedir, '_config.yml'
    config_data = SafeYAML.load_file config_path, safe: true
    return unless config_data
    nav_data = (config_data['navigation'] || [])
    update_navigation_data nav_data, pages_front_matter_by_title(basedir)
    write_navigation_data_to_config_file config_path, nav_data
  end

  def self.pages_front_matter_by_title(basedir)
    Dir[File.join basedir, 'pages', '**', '*.md'].map do |f|
      front_matter = SafeYAML.load_file f, safe: true
      [front_matter['title'], front_matter]
    end.to_h
  end
  private_class_method :pages_front_matter_by_title

  def self.update_navigation_data(nav_data, pages_front_matter_by_title)
    nav_data_by_title = nav_data.map { |nav| [nav['text'].downcase, nav] }.to_h

    pages_front_matter_by_title.each do |title, front_matter|
      page_nav = page_nav title, front_matter
      title = title.downcase

      if nav_data_by_title.member? title
        nav_data_by_title[title].merge! page_nav
      elsif front_matter.member? 'parent'
        add_child_to_parent title, front_matter, page_nav, nav_data_by_title
      else
        nav_data << page_nav
      end
    end
  end
  private_class_method :update_navigation_data

  def self.page_nav(title, front_matter)
    { 'text' => title,
      'url' => "#{front_matter['permalink'].split('/').last}/",
      'internal' => true,
    }
  end
  private_class_method :page_nav

  def self.add_child_to_parent(title, child, page_nav, nav_data_by_title)
    children = children child, nav_data_by_title
    children_by_title = children.map { |i| [i['text'].downcase, i] }.to_h

    if children_by_title.member? title
      children_by_title[title].merge! page_nav
    else
      children << page_nav
    end
  end
  private_class_method :add_child_to_parent

  def self.children(child, nav_data_by_title)
    parent = child['parent'].downcase
    unless nav_data_by_title.member?(parent)
      fail StandardError, 'Parent page not present in existing ' \
        "config: #{child['parent']}\nNeeded by: #{child['text']}"
    end
    nav_data_by_title[parent]['children'] ||= []
  end
  private_class_method :children

  def self.write_navigation_data_to_config_file(config_path, nav_data)
    lines = []
    in_navigation = false
    open(config_path).each_line do |line|
      if !in_navigation && line.start_with?('navigation:')
        lines << line
        lines << nav_data.to_yaml["---\n".size..-1]
        in_navigation = true
      elsif in_navigation
        unless line.start_with?(' ') || line.start_with?('-')
          in_navigation = false
          lines << line
        end
      else
        lines << line
      end
    end
    File.write config_path, lines.join
  end
  private_class_method :write_navigation_data_to_config_file
end
