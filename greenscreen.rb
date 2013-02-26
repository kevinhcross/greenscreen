require 'rubygems'
require 'sinatra'
require 'erb'
require 'rexml/document'
require 'hpricot'
require 'open-uri'
require 'yaml'
require 'json'
require 'net/http'
require 'uri'

def get_data(url)
  resp = Net::HTTP.get_response(URI.parse(url))
  data = resp.body
  # This odd looking gsub is a workaround for this bug: https://issues.jenkins-ci.org/browse/JENKINS-13556
  data.gsub /\x1B/, ""
end

# Parse the json output from Jenkins to create job objects
def get_jobs(url)
  result = JSON.parse(get_data(url))
  job_list = []
  result["jobs"].each do |job_data|
    #logger.info "Doing #{job_data["name"]}"

    build_score = -1
    build_text = ""
    test_score = -1
    test_text = ""
    health_report = job_data["healthReport"]
    if health_report
      health_report_build = health_report[0]
      if health_report_build
        build_score = health_report_build["score"]
        build_text = health_report_build["description"]
      end
      health_report_test = health_report[0]
      if health_report_test
        test_score = health_report_test["score"]
        test_text = health_report_test["description"]
      end
    end
    
    lastCompleted = DateTime.strptime("0", '%Q')
    last_completed_build = job_data["lastCompletedBuild"]
    if last_completed_build
      last_job_url = last_completed_build["url"] + "/api/json"
      #logger.info "last_job_url = #{last_job_url}"
      last_comp_data = JSON.parse(get_data(last_job_url))
      lastCompleted = DateTime.strptime("#{last_comp_data["timestamp"]}", '%Q')
    end

    job = JenkinsJob.new job_data["name"], job_data["color"], job_data["url"], build_score, build_text, test_score, test_text, lastCompleted
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
  logger.info "servers : #{servers}"
  return "Add the details of build server to the config.yml file to get started" unless servers
  
  @sorted_job_list = []

  servers.each do |server|
    logger.info "url : #{server["url"]}"
    url = URI.escape(server["url"] + "/api/json?depth=1")
    #logger.info "Getting data from #{url}"
    @sorted_job_list = sort_jobs(get_jobs(url))
    @sorted_job_list.each { |j| logger.info j }
  end

  # If there are no failing jobs then we need to display something
  if @sorted_job_list.size == 0 
    logger.info "Adding the all good job"
    job = JenkinsJob.new "All Good!", "green", url, 100
    @sorted_job_list << job
  end

  @columns = 1.0
  @columns = 2.0 if @sorted_job_list.size > 4
  @columns = 3.0 if @sorted_job_list.size > 10
  @columns = 4.0 if @sorted_job_list.size > 21
  
  @rows = (@sorted_job_list.size / @columns).ceil
  logger.info "sorted_job_list size : #{@sorted_job_list.size}"
  logger.info "rows : #{@rows}"

  erb :index
end

class JenkinsJob
  attr_accessor :name, :color, :url, :health, :build_text, :test_score, :test_text, :lastCompleted
  def initialize(name, color, url, health, build_text, test_score, test_text, lastCompleted)
    @name = name
    @color = color
    @url = url
    @health = health
    @build_text = build_text
    @test_score = test_score
    @test_text = test_text
    @lastCompleted = lastCompleted
  end
  def to_s
    "#{@name}\t#{@color}\t#{@health}\t#{@build_text}\t#{@test_score}\t#{@test_text}\t#{@url}\t#{@lastCompleted.strftime("%+")}"
  end
end

