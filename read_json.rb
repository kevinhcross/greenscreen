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



url = "http://localhost:8080/api/json"
resp = Net::HTTP.get_response(URI.parse(url))
data = resp.body

# we convert the returned JSON data to native Ruby
# data structure - a hash
result = JSON.parse(data)
job_list = []

result["jobs"].each do |job|
  job = JenkinsJob.new job["name"], job["color"], job["url"]
  job_list << job
end

sorted_and_filtered = []

["red", "yellow", "grey"].each do |color|
  job_list.select {|j| j.color == color}.each { |j| sorted_and_filtered << j }
end

sorted_and_filtered.each { |j| puts j }

