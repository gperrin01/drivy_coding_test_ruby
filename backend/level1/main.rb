require "json"
require 'pry'

# get the Json object from data.json and prepare output hash
file = File.read('data.json')
data = JSON.parse(file)
output = {"rentals" => []}

# Two methods to find a car based on its id and get the number of days in a rental
def find_car_by_id data, id
  data['cars'].detect{|car| car['id'] == id}
end

def number_days rental
  ( Date.parse(rental['end_date']) - Date.parse(rental['start_date']) ).to_i + 1
end

# iterate through the array of rental IDs to calculate their price
data["rentals"].each do |rental|
  car = find_car_by_id(data, rental['car_id'])
  # time component: rental days * car's price per day
  n_days = number_days(rental)
  ppday = car['price_per_day']
  time_cost = n_days * ppday
  # distance componebt: km * cost per km
  distance_cost = rental['distance'] * car['price_per_km']

  # update this rental in the output object
  output['rentals'] << {"id" => rental['id'], 'price' => time_cost + distance_cost}
end

# create the output file - using a different name so you can compare with the expected ouput
File.new('output2.json', 'w+').write(JSON.pretty_generate output)
