class WebyNewsSliderComponent < Component
  component_settings :news_category, :width, :height, :quantity, :timer

  def news(site)
    news_category.blank? ?
      site.news_sites.where(site_id: site.id).joins(:news).available_fronts.where('journal_news.repository_id is not null').order('position desc').limit(quantity) :
        site.news_sites.where(site_id: site.id).joins(:news).available.tagged_with(news_category.to_s.mb_chars.downcase.to_s).where('repository_id is not null').order('position desc')
  end

  alias_method :_width, :width
  def width
    _width.blank? ? '400' : _width
  end

  alias_method :_height, :height
  def height
    _height.blank? ? '300' : _height
  end

  alias_method :_quantity, :quantity
  def quantity
    _quantity.blank? ? '5' : _quantity
  end

  alias_method :_timer, :timer
  def timer
    _timer.blank? ? '7' : _timer
  end

  def default_alias
    news_category
  end
end
