require_relative 'csv_response'
require_relative 'json_response'
require_relative 'xlsx_response'
require_relative 'pdf_response'
require_relative 'html_response'
require 'erb'
require 'nokogiri'

# this is a generic wrapper for reports reponses. JasperReports do not 
# need a reponse wrapper and can return reports on formats using the to_FORMAT
# convention. "Classic" AS reports need a wrapper to render the report in a
# specific format.
class ReportResponse
 
  attr_accessor :report
  attr_accessor :base_url

  def initialize(report,  params = {}  )
    @report = report
    @params = params 
  end

  def generate
    if  @report.is_a?(JasperReport) 
      format = @report.format    
      String.from_java_bytes( @report.render(format.to_sym, @params) ) 
    else
      file = File.join( File.dirname(__FILE__), "../../views/reports/report.erb")
      @params[:html_report] ||= proc { ReportErbRenderer.new(@report, @params).render(file) }

      format = @report.format

      klass = Object.const_get("#{format.upcase}Response")
      klass.send(:new, @report, @params).generate
    end
  end

end

class ReportErbRenderer

  include ERB::Util

  def initialize(report, params)
    @report = report
    @params = params
  end

  def layout?
    @params.fetch(:layout, true)
  end

  def render(file)
    HTMLCleaner.new.clean(ERB.new( File.read(file) ).result(binding))
  end

  def format_4part(s)
    unless s.nil?
      ASUtils.json_parse(s).compact.join('.')
    end
  end

  def text_section(title, value)
    # Sick of typing these out...
    template = <<EOS
        <section>
            <h3>%s</h3>
            %s
        </section>
EOS

    template % [h(title), preserve_newlines(h(value))]
  end

  def subreport_section(title, subreport, *subreport_args)
    # Sick of typing these out...
    template = <<EOS
        <section>
            <h3>%s</h3>
             %s
        </section>
EOS

    template % [h(title), insert_subreport(subreport, *subreport_args)]
  end

  def format_date(date)
    unless date.nil?
      h(date.to_s)
    end
  end

  def format_boolean(boolean)
    if boolean
      "Yes"
    else
      "No"
    end
  end

  def format_number(number)
    unless number.nil?
      h(sprintf('%.2f', number))
    end
  end

  def insert_subreport(subreport, params)
    report_model = Kernel.const_get(subreport)
    ReportResponse.new(report_model.new(params.merge(:format => 'html'), @report.job, @report.db),
                       :layout => false).generate
  end

  def transform_text(s)
    return '' if s.nil?

    # The HTML to PDF library doesn't currently support the "break-word" CSS
    # property that would let us force a linebreak for long strings and URIs.
    # Without that, we end up having our tables chopped off, which makes them
    # not-especially-useful.
    #
    # Newer versions of the library might fix this issue, but it appears that the
    # licence of the newer version is incompatible with the current ArchivesSpace
    # licence.
    #
    # So, we wrap runs of characters in their own span tags to give the renderer
    # a hint on where to place the line breaks.  Pretty terrible, but it works.
    #
    if @report.format === 'pdf'
      escaped = h(s)

      # Exciting regexp time!  We break our string into "tokens", which are either:
      #
      #   - A single whitespace character
      #   - A HTML-escaped character (like '&amp;')
      #   - A run of between 1 and 5 letters
      #
      # Each token is then wrapped in a span, ensuring that we don't go too
      # long without having a spot to break a word if needed.
      #
      escaped.scan(/[\s]|&.*;|[^\s]{1,5}/).map {|token|
        if token.start_with?("&") || token =~ /\A[\s]\Z/
          # Don't mess with &amp; and friends, nor whitespace
          token
        else
          "<span>#{token}</span>"
        end
      }.join("")
    else
      h(s)
    end
  end

  def preserve_newlines(s)
    transform_text(s).gsub(/(?:\r\n)+/,"<br>");
  end

  class HTMLCleaner

    def clean(s)
      doc = Nokogiri::HTML(s)

      # Remove empty dt/dd pairs
      doc.css("dl").each do |definition|
        definition.css('dt, dd').each_slice(2) do |dt, dd|
          if dd.text().strip.empty?
            dt.remove
            dd.remove
          end
        end
      end

      # Remove empty dls
      doc.css("dl").each do |dl|
        if dl.text().strip.empty?
          dl.remove
        end
      end

      # Remove empty tables
      doc.css("table").each do |table|
        if table.css("td").empty?
          table.remove
        end
      end

      # Remove empty sections
      doc.css("section").each do |section|
        if section.children.all? {|elt| elt.is_a?(Nokogiri::XML::Comment) || elt.text.strip.empty? || elt.name == 'h3'}
          section.remove
        end
      end

      doc.to_xhtml
    end

  end

end
