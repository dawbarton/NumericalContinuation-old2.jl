#--- Generic functions for creating coverings

function add_projection! end
function update_projection! end

function cover! end

function get_prob end
function get_charts end
function get_current_chart end
function get_chart_label end
function get_chart_type end
function get_chart_u end
function get_chart_t end
function get_chart_data end

# TODO: tidy up the notion of ChartInfo - probably shouldn't exist in this form and should be combined with the chart save information (i.e., what gets stored on disk, if anything)
struct ChartInfo{T}
    label::Int64
    type::Symbol
    vars::Dict{String, Vector{T}}
    data::Any
end

function ChartInfo(prob, chart)
    T = get_numtype(prob)
    label = get_chart_label(chart)
    type = get_chart_type(chart)
    u = get_chart_u(chart)
    data = get_chart_data(chart)
    _vars = get_vars(prob)
    _mfuncs = get_mfuncs(prob)
    vars = Dict{String, Vector{T}}()
    for var in Iterators.drop(_vars, 1) # ignore "all"
        vars[var] = u[get_indices(_vars, _vars[var])]
    end
    for mfunc in _mfuncs
        vars[mfunc] = [get_mfunc_value(_mfuncs, _mfuncs[mfunc], data)]
    end
    return ChartInfo(label, type, vars, data)
end
