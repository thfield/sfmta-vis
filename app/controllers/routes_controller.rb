class RoutesController < ApplicationController
  before_action :set_route, only: [:busroute, :busstops, :frequency]

  def busroute
    # shapesFromMyRoute = Trip.includes(:shapes).where(id: @stoptimesOnMyRoute.first.trip_id)[0].shapes
    # inbound_trip = @stoptimesOnMyRoute.where(:trips => {direction_id: 0}).first
    # outbound_trip = @stoptimesOnMyRoute.where(:trips => {direction_id: 1}).first

    inquiry_period = @endHour - @startHour

    myStops = @stoptimesOnMyRoute.uniq.pluck(:stop_id)
    frequencies = Array.new
    myStops.each do |stop|
      frequencies.push( @stoptimesOnMyRoute.where(stop_id: stop).length )
    end
    stopavg = frequencies.inject{ |sum, el| sum + (el/inquiry_period) }.to_f / frequencies.size

    distinct_trip_ids = @stoptimesOnMyRoute.map(&:trip_id).uniq
    distinct_shape_nums_from_myRoutes = Trip.where(id: distinct_trip_ids).map(&:shape_id).uniq
    # distinct_shapes_from_myRoutes = Trip.where(id: distinct_trip_ids).select(:shape_id).distinct
    features = Array.new
    distinct_shape_nums_from_myRoutes.each do |pathway|
      shapes_on_pathway = Shape.where(shape_num: pathway)
      coordinates = Array.new
      shapes_on_pathway.each do |point|
        temp = [point.shape_pt_lon.to_f,point.shape_pt_lat.to_f]
        coordinates.push(temp)
      end
      features.push({
        'type'=>'Feature',
        'properties' => {
          'route' => @whichRoute,
          'shape' => pathway,
          'start' => @startHour,
          'end' => @endHour,
          'freq' => stopavg.floor
        },
        'geometry' => {'type' => 'LineString',
                       'coordinates' => coordinates
                      }
      })
    end
    @returndata = {
    "type" => "FeatureCollection",
    "features" => features
    }

    if @returndata['features'].length > 0
      render json: @returndata
    else
      render html: 'error: no trips in requested timeframe'
    end
  end

  def busstops
    myStops = @stoptimesOnMyRoute.uniq.pluck(:stop_id)
    @data = Array.new

    myStops.each do |stop|
      temp = Hash.new
      foo = Stop.where(id: stop)[0]
      temp['num'] = @stoptimesOnMyRoute.where(stop_id: stop).length
      temp['lon'] = foo.stop_lon.to_f
      temp['lat'] = foo.stop_lat.to_f
      @data.push(temp)
    end

    render json: @data
  end

  def frequency
    myStops = @stoptimesOnMyRoute.uniq.pluck(:stop_id)
    frequencies = Array.new

    myStops.each do |stop|
      frequencies.push( @stoptimesOnMyRoute.where(stop_id: stop).length )
    end
    stopavg = frequencies.inject{ |sum, el| sum + el }.to_f / frequencies.size

    @data = {'route'=>@whichRoute, 'avg'=> stopavg.floor}
    render json: @data
  end



  private
    # Use callbacks to share common setup or constraints between actions.
    def set_route
      #zeroday is probably the day you seeded your DB
      zeroday = DateTime.parse('2015-12-02')
      params[:end] ||= params[:start].to_i + 1

      if params[:end].to_i < params[:start].to_i
        params[:end] = params[:start].to_i + 1
      end

      @whichRoute = params[:id]
      @startHour = params[:start].to_i
      @endHour = params[:end].to_i

      # @whichRoute = 10867
      # @startHour = 12
      # @endHour = 13

      allStops = StopTime.includes({trip: :route}, :stop).where( arrival_time: (zeroday.change( { hour: @startHour } )..zeroday.change( { hour: @endHour } )) )
      myRoutesTrips = Array.new
      #only look at trips that happen on the weekdays (serivce_id == 1)
      Trip.where(route_id: @whichRoute, service_id: 1).each do |trip|
        myRoutesTrips.push(trip.id)
      end

      @stoptimesOnMyRoute = allStops.where(trip_id: myRoutesTrips)

    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def route_params
      params[:route].permit(:start, :end)
    end
end
