class Site < ActiveRecord::Base
  before_save :clear_per_page

  def to_label
    "#{name}#{".#{main_site.name}" if main_site} (#{title})"
  end

  scope :name_or_description_like, lambda { |text|
    where('lower(sites.name) LIKE lower(:text) OR lower(sites.description) LIKE lower(:text) OR lower(sites.title) LIKE lower(:text)',
          {:text => "%#{text}%"})
  }

  scope :ordered_by_front_pages, lambda { |text|
    page_query = Page.select("coalesce(max(pages.updated_at),'1900-01-01')").
      front.available.
      where("pages.site_id = sites.id").to_sql

    where('lower(sites.name) LIKE lower(:text)
         OR lower(sites.description) LIKE lower(:text)
         OR lower(sites.title) LIKE lower(:text)',
       {:text => "%#{text}%"}).
    order("(#{page_query}) desc")
  }

  validates :url,
    presence: true,
    format: {with: /^http[s]{,1}:\/\/[\w\.\-\%\#\=\?\&]+\.([\w\.\-\%\#\=\?\&]+\/{,1})*/i}

  validates :name,
    presence: true,
     uniqueness: {:scope => :parent_id},
      format: {with: /^[a-z0-9_\-]+$/}


  validates :per_page,
    presence: true,
    format: {with: /([0-9]+[,\s]*)+[0-9]*/}

  validates :title,
    presence: true,
    :length => {:maximum => 50}

  validates :theme, presence: true

  has_many :subsites,
    foreign_key: :parent_id,
    class_name: "Site"

  belongs_to :main_site,
    foreign_key: :parent_id,
    class_name: "Site"

  has_many :roles

  has_many :views

  has_many :menus, dependent: :delete_all, order: :id
  has_many :menu_items, :through => :menus

  has_many :pages,
    include: :i18ns,
    dependent: :delete_all

  has_many :pages_i18ns, through: :pages, source: :i18ns

  has_many :banners, order: :position

  has_many :styles, dependent: :destroy, order: 'styles.position desc'

  has_many :components, order: 'place_holder, position asc', dependent: :destroy
  has_many :root_components, order: :position, class_name: 'Component', conditions: "place_holder !~ '^\\d*$'"

  belongs_to :repository, :foreign_key => "top_banner_id"
  has_many :repositories

  has_many :extensions

  has_and_belongs_to_many :locales

  has_and_belongs_to_many :groupings

  validate :at_least_one_locale

  def at_least_one_locale
    if self.locales.length < 1
      errors.add(:locales, I18n.t("site_need_at_least_one_locale"))
    end
  end

  def has_extension(extension)
    extensions.select {|ext| ext.name = extension.to_s }.any?
  end

  has_attached_file :top_banner, :url => "/uploads/:site_id/:style_:basename.:extension"
  private
  def clear_per_page
    self.per_page.gsub!(/[^\d,]/,'')
    self.per_page.gsub!(',,',',')
  end
end
