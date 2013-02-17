require 'json'
require 'net/http'

class JenkinsJob
  attr_accessor :color
  def initialize(name, color, url)
    @name = name
    @color = color
    @url = url
  end
  def to_s
    "#{@name}\t#{@color}\t#{@url}"
  end
end

def get_data(url)
  resp = Net::HTTP.get_response(URI.parse(url))
  data = resp.body
end

# Parse the json output from Jenkins to create job objects
def get_jobs(url)
  result = JSON.parse(get_data(url))
  job_list = []
  result["jobs"].each do |job|
    job = JenkinsJob.new job["name"], job["color"], job["url"]
    job_list << job
  end
  job_list
end

# We are only interested in failing jobs and also we want them sorted
def sort_jobs(job_list)
  sorted_and_filtered = []
  ["red", "yellow", "grey"].each do |color|
    job_list.select {|j| j.color == color}.each { |j| sorted_and_filtered << j }
  end
  sorted_and_filtered
end

url = "http://localhost:8080/api/json"
sorted_job_list = sort_jobs(get_jobs(url))
sorted_job_list.each { |j| puts j }

