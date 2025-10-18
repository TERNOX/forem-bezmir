#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'pathname'

PHRASE_MAP = [
  ["Contact us", "Зв'яжіться з нами"],
  ["Contact", "Зв'язатися"],
  ["If you have any questions.", "Якщо у вас є запитання."],
  ["If you continue having trouble.", "Якщо у вас і надалі виникатимуть труднощі."],
  ["If there is anything we can help with.", "Якщо ми можемо з чимось допомогти."],
  ["continue having trouble", "продовжуєте мати труднощі"],
  ["we can help", "ми можемо допомогти"],
  ["anything we can help with", "щось, з чим ми можемо допомогти"],
  ["Log in", "Увійти"],
  ["Log out", "Вийти"],
  ["Sign in", "Увійти"],
  ["Sign up", "Зареєструватися"],
  ["Sign Out", "Вийти"],
  ["Sign In", "Увійти"],
  ["Sign Up", "Зареєструватися"],
  ["Add comment", "Додати коментар"],
  ["Add Comment", "Додати коментар"],
  ["Add a comment", "Додайте коментар"],
  ["Add", "Додати"],
  ["Delete", "Видалити"],
  ["Edit", "Редагувати"],
  ["Update", "Оновити"],
  ["Create", "Створити"],
  ["Cancel", "Скасувати"],
  ["Save", "Зберегти"],
  ["Submit", "Надіслати"],
  ["Search", "Пошук"],
  ["Loading", "Завантаження"],
  ["Follow", "Стежити"],
  ["Following", "Стежать"],
  ["Follower", "Підписник"],
  ["Followers", "Підписники"],
  ["Followed", "Стежать"],
  ["Follow back", "Стежити у відповідь"],
  ["Like", "Подобається"],
  ["Likes", "Вподобання"],
  ["Comment", "Коментар"],
  ["Comments", "Коментарі"],
  ["Reactions", "Реакції"],
  ["Reaction", "Реакція"],
  ["Share", "Поділитися"],
  ["Settings", "Налаштування"],
  ["Profile", "Профіль"],
  ["Community", "Спільнота"],
  ["Dashboard", "Панель"],
  ["Notifications", "Сповіщення"],
  ["Organization", "Організація"],
  ["Organizations", "Організації"],
  ["Tag", "Тег"],
  ["Tags", "Теги"],
  ["Article", "Стаття"],
  ["Articles", "Статті"],
  ["Post", "Публікація"],
  ["Posts", "Публікації"],
  ["Story", "Історія"],
  ["Stories", "Історії"],
  ["Team", "Команда"],
  ["Teams", "Команди"],
  ["Members", "Учасники"],
  ["Member", "Учасник"],
  ["Name", "Ім'я"],
  ["Email", "Електронна пошта"],
  ["Password", "Пароль"],
  ["Username", "Ім'я користувача"],
  ["Title", "Заголовок"],
  ["Description", "Опис"],
  ["Summary", "Коротко"],
  ["View", "Переглянути"],
  ["Views", "Перегляди"],
  ["Read", "Читати"],
  ["Reading", "Читання"],
  ["Report", "Поскаржитися"],
  ["Report abuse", "Поскаржитися"],
  ["Blocked", "Заблоковано"],
  ["Block", "Заблокувати"],
  ["Unblock", "Розблокувати"],
  ["Ban", "Заборонити"],
  ["Unban", "Зняти заборону"],
  ["Disable", "Вимкнути"],
  ["Enable", "Увімкнути"],
  ["Success", "Успіх"],
  ["Error", "Помилка"],
  ["Warning", "Попередження"],
  ["Continue", "Продовжити"],
  ["Continue editing", "Продовжити редагування"],
  ["Preview", "Попередній перегляд"],
  ["Schedule", "Запланувати"],
  ["Publish", "Опублікувати"],
  ["Published", "Опубліковано"],
  ["Draft", "Чернетка"],
  ["Drafts", "Чернетки"],
  ["New", "Новий"],
  ["New post", "Нова публікація"],
  ["New post title here", "Заголовок нової публікації"],
  ["Organization", "Організація"],
].uniq.sort_by { |english, _| -english.length }

WORD_MAP = {
  'if' => 'якщо',
  'you' => 'ви',
  'your' => 'ваш',
  'have' => 'маєте',
  'any' => 'будь-які',
  'question' => 'запитання',
  'questions' => 'запитання',
  'trouble' => 'труднощі',
  'continue' => 'продовжувати',
  'having' => 'маючи',
  'help' => 'допомога',
  'there' => 'там',
  'is' => 'є',
  'anything' => 'щось',
  'we' => 'ми',
  'can' => 'можемо',
  'here' => 'тут',
  'response' => 'відповідь',
  'completing' => 'завершення',
  'survey' => 'опитування',
  'and' => 'і',
  'or' => 'або',
  'of' => 'з',
  'for' => 'для',
  'by' => 'від',
  'with' => 'з',
  'to' => 'до',
  'from' => 'від',
  'in' => 'у',
  'on' => 'на',
  'at' => 'о',
  'yes' => 'так',
  'no' => 'ні',
  'day' => 'день',
  'days' => 'дні',
  'month' => 'місяць',
  'months' => 'місяці',
  'year' => 'рік',
  'years' => 'роки',
  'hour' => 'година',
  'hours' => 'години',
  'minute' => 'хвилина',
  'minutes' => 'хвилини',
  'second' => 'секунда',
  'seconds' => 'секунди',
  'ago' => 'тому',
  'about' => 'приблизно',
  'less' => 'менше',
  'than' => 'ніж',
  'over' => 'понад',
  'expired' => 'прострочено',
  'user' => 'користувач',
  'users' => 'користувачі',
  'team' => 'команда',
  'teams' => 'команди',
  'organization' => 'організація',
  'organizations' => 'організації',
  'member' => 'учасник',
  'members' => 'учасники',
  'admin' => 'адмін',
  'admins' => 'адміни',
  'page' => 'сторінка',
  'pages' => 'сторінки',
  'home' => 'головна',
  'hello' => 'привіт',
  'welcome' => 'ласкаво просимо',
  'thank' => 'дякуємо',
  'thanks' => 'дякуємо',
  'please' => 'будь ласка',
}.freeze

BASE_PATH = Pathname.new('config/locales')

FILES = %w[
  en.yml
  utils/en.yml
  devise_invitable.en.yml
  languages/en.yml
  lib/en.yml
  devise.en.yml
  misc/en.yml
  services/en.yml
  helpers/en.yml
  controllers/en.yml
  controllers/api/en.yml
  controllers/admin/en.yml
  kaminari.en.yml
  liquid_tags/en.yml
  views/credits/en.yml
  views/article_form/en.yml
  views/moderations/en.yml
  views/settings/en.yml
  views/feedback/en.yml
  views/comments/en.yml
  views/articles/en.yml
  views/auth/en.yml
  views/dashboard/en.yml
  views/search/en.yml
  views/main/en.yml
  views/tags/en.yml
  views/reactions/en.yml
  views/misc/en.yml
  views/liquids/en.yml
  views/users/en.yml
  views/editor/en.yml
  views/notifications/en.yml
  views/subforems/en.yml
  views/survey/en.yml
  views/podcasts/en.yml
  views/organizations/en.yml
  views/listings/en.yml
  views/manager/en.yml
  views/stories/en.yml
  views/actions/en.yml
  views/admin/en.yml
  validators/en.yml
  mailers/en.yml
  decorators/en.yml
  concerns/en.yml
  models/en.yml
].freeze

WORD_REGEX = /[A-Za-z]+/

def translate_text(text)
  result = text.dup
  PHRASE_MAP.each do |english, ukrainian|
    result.gsub!(english, ukrainian)
  end
  result.gsub(WORD_REGEX) do |word|
    lower = word.downcase
    replacement = WORD_MAP[lower]
    next word unless replacement

    if word == word.upcase
      replacement.upcase
    elsif word[0] == word[0].upcase
      replacement.capitalize
    else
      replacement
    end
  end
end

def translate_value(value)
  case value
  when String
    translate_text(value)
  when Array
    value.map { |item| translate_value(item) }
  when Hash
    value.transform_values { |val| translate_value(val) }
  else
    value
  end
end

FILES.each do |relative|
  source_path = BASE_PATH.join(relative)
  next unless source_path.exist?

  data = YAML.load_file(source_path)
  next unless data.is_a?(Hash) && data.keys.size == 1

  root_key = data.keys.first
  translated = translate_value(data[root_key])
  uk_data = { 'uk' => translated }

  basename = source_path.basename.to_s
  destination = if basename.end_with?('.en.yml')
                  Pathname.new(source_path.to_s.sub(/\.en\.yml\z/, '.uk.yml'))
                elsif basename == 'en.yml'
                  source_path.dirname.join('uk.yml')
                else
                  source_path.sub_ext('.uk.yml')
                end

  destination.dirname.mkpath
  comment = "# Original locale: #{source_path.relative_path_from(BASE_PATH)}\n"
  yaml_text = uk_data.to_yaml(line_width: -1)
  File.write(destination, comment + yaml_text)
  puts "Created #{destination}"
end
