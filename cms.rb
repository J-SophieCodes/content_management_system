require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'tilt/erubis'
require 'redcarpet'
require 'fileutils'
require 'yaml'
require 'bcrypt'

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

before do
  session[:login] ||= nil

  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    { name: File.basename(path), content: File.read(path) }
  end
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def render_content(file)
  case File.extname(file[:name])
  when ".md"
    render_markdown(file[:content])
  when ".txt"
    headers["Content-Type"] = "text/plain"
    file[:content]
  end
end

def load_file(name)
  file = @files.find { |file| file[:name] == params[:filename] }
  return file if file

  session[:message] = "#{name} does not exist."
  redirect "/"
end

def load_content(filename)
  file = load_file(filename)
  render_content(file)
end

def detect_error(filename)
  if filename.empty?
    "A name is required."
  elsif ![".md", ".txt"].include?(File.extname(filename))
    "Only '.md' or '.txt' documents are supported."
  elsif File.file?(File.join(data_path, filename))
    "'#{filename}' already exists."
  end
end

def load_users_db
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users_db.yml", __FILE__)
  else
    File.expand_path("../users_db.yml", __FILE__)
  end

  YAML.load_file(credentials_path)
end

def login_valid?(username, password)
  users_db = load_users_db
  users_db.key?(username) && BCrypt::Password.new(users_db[username]) == password
end

def signed_in?
  !session[:login].nil?
end

def access_status
  return if signed_in?
  
  session[:message] = "You must be signed in to do that."
  redirect "/"
end

get '/' do
  erb :files_list
end

get '/users/login' do
  erb :login
end

post '/users/login' do
  username = params[:username]
  password = params[:password]

  if login_valid?(username, password)
    session[:login] = username
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid Credentials"
    status 422
    erb :login
  end
end

post '/users/logout' do
  session[:login] = nil
  session[:message] = "You have successfully logged out."
  redirect "/"
end

get '/new' do
  access_status

  erb :create_file
end

post '/new' do
  access_status

  if error = detect_error(params[:filename])
    session[:message] = error
    status 422
    erb :create_file
  else
    file_path = File.join(data_path, params[:filename])
    File.open(file_path, "w")

    session[:message] = "'#{params[:filename]}' has been created."
    redirect "/"
  end
end

get '/:filename' do
  load_content(params[:filename])
end

post '/:filename' do
  access_status

  file_path = File.join(data_path, params[:filename])
  File.write(file_path, params[:content])

  session[:message] = "'#{params[:filename]}' has been updated."
  redirect "/"
end

get '/:filename/edit' do
  access_status

  @file = load_file(params[:filename])
  erb :edit_file
end

post '/:filename/delete' do
  access_status

  file_path = File.join(data_path, params[:filename])
  File.delete(file_path)

  session[:message] = "'#{params[:filename]}' has been deleted."
  redirect "/"
end