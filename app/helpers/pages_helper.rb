module PagesHelper
  def next_class_day
    now = Time.current.in_time_zone("Central Time (US & Canada)")
    wday = now.wday  # 0=Sun, 6=Sat
    hour = now.hour
    min = now.min

    # Wednesday if between Saturday 2 pm and Wednesday 8:30 pm
    return "Wednesday at 8:30 pm" if wday == 6 && (hour > 14 || (hour == 14 && min >= 0))
    return "Wednesday at 8:30 pm" if wday.between?(0, 2)  # Sun, Mon, Tue
    return "Wednesday at 8:30 pm" if wday == 3 && (hour < 20 || (hour == 20 && min < 30))

    "Saturday at 2 pm"
  end
end
