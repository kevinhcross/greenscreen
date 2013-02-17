require 'rubygems'
require 'sinatra'
require 'erb'
require 'rexml/document'
require 'hpricot'
require 'open-uri'
require 'yaml'
require 'json'
require 'net/http'

def get_data(url)
  resp = Net::HTTP.get_response(URI.parse(url))
  data = resp.body
end

# Parse the json output from Jenkins to create job objects
def get_jobs(url)
  result = JSON.parse(get_data(url))
  job_list = []
  result["jobs"].each do |job_data|

    healthReport = job_data["healthReport"][0]
    score = healthReport ? healthReport["score"] : -1

    job = JenkinsJob.new job_data["name"], job_data["color"], job_data["url"], score
    job_list << job
  end
  job_list
end

# We are only interested in failing jobs and also we want them sorted
def sort_jobs(job_list)
  sorted_and_filtered = []
  [/red.*/, /yellow.*/, /grey.*/].each do |color|
    job_list.select {|j| j.color =~ color}.each { |j| sorted_and_filtered << j }
  end
  sorted_and_filtered
end

get '/' do
  servers = YAML.load_file 'config.yml'
  return "Add the details of build server to the config.yml file to get started" unless servers
  
  @sorted_job_list = []

  servers.each do |server|
    url = server["url"] + "/api/json?depth=1"
    puts "Getting data from #{url}"
    @sorted_job_list = sort_jobs(get_jobs(url))
    @sorted_job_list.each { |j| puts j }
  end

  @columns = 1.0
  @columns = 2.0 if @sorted_job_list.size > 4
  @columns = 3.0 if @sorted_job_list.size > 10
  @columns = 4.0 if @sorted_job_list.size > 21
  
  @rows = (@sorted_job_list.size / @columns).ceil

  erb :index
end

class JenkinsJob
  attr_accessor :name, :color, :url, :health
  def initialize(name, color, url, health)
    @name = name
    @color = color
    @url = url
    @health = health
  end
  def to_s
    "#{@name}\t#{@color}\t#{@health}\t#{@url}"
  end
end

