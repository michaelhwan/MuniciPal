require 'geokit'

class AddressesController < ApplicationController

  respond_to :html, :json

  def index
  #index takes a lat/lng pair, an address, a district, or a person,
  #and returns details about representatives, events, items, and attachments
  #as well as the original data
    @response = { :lat                    => nil,
                  :lng                    => nil,
                  :address                => "",
                  :in_district       => false,
                  :person_title      => "",
                  :district       => nil,
                  :event_items       => nil,
                  :attachments => nil,
                  :events => nil
                }

    #SET THE VALUES IN THE RESPONSE TO THEIR VALUES IN THE PARAMS
    params.each_key{|key| @response[key.to_sym] = params[key.to_sym]}
    #move block below to own route? - seem like params' key should be :title, not :title.value?
    # /people/byTitle/:title (title = mayor, manager, councilmember, all)
    if params[:mayor]
      @response[:person_title] = "mayor"
    elsif params[:manager]
      @response[:person_title] = "manager"
    else
      @response[:person_title] = "councilmember"
    end

    # address given; geocode to get lat/lon
    # /districts/byAddress/:address -> lat,lon

    if not @response[:address].empty?
      #if address is given:
      @geocoded_address = Geokit::Geocoders::MultiGeocoder.geocode @response[:address]
      @response[:lat] = @geocoded_address.lat
      @response[:lng]  = @geocoded_address.lng
    end

    if @response[:lat] && @response[:lng]
      @response[:district] = CouncilDistrict.getDistrict @response[:lat], @response[:lng] #@lat, @lng
    end

    if @response[:district] and @response[:district].to_i.between?(1,6) # Valid districts in Mesa are 1-6 (inclusive)
        @response[:in_district] = true
        @response[:event_items] = EventItem.current.with_matters.in_district(@response[:district]).order('date DESC') +
                     EventItem.current.with_matters.no_district.order('date DESC') if @response[:in_district]
    elsif (@response[:district] and @response[:district] == "all") or
           @response[:person_title] == "mayor" or
           @response[:person_title] == "manager"
      @response[:event_items] = EventItem.current.with_matters.order('date DESC') #all
      #the following line is a legacy thing from a variable in JS that flags whether a user was in the city
      @response[:in_district] = true;
    end

    if @response[:event_items]
      @response[:attachments] = @response[:event_items].map(&:attachments) #see http://ablogaboutcode.com/2012/01/04/the-ampersand-operator-in-ruby/
      @response[:events] = @response[:event_items].map(&:event).uniq #see http://ablogaboutcode.com/2012/01/04/the-ampersand-operator-in-ruby/
    end

    respond_with(@response)
  end
end
