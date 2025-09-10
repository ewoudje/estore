defmodule Estore.ICS do
  @type x_value() :: {:x, String.t()}
  @type attribute() ::
          {:altrep, String.t()}
          | {:common_name, String.t()}
          | {:cutype, :individual | :group | :resource | :room | :unkown | x_value()}
          | {:delegated_from, [String.t()]}
          | {:delegated_to, [String.t()]}
          | {:dir, String.t()}
          | {:encoding, :eight_bit | :base64 | x_value()}
          | {:fmttype, String.t()}
          | {:fbtype, :free | :busy | :busy_tentative | :busy_unavailable | x_value()}
          | {:language, String.t()}
          | {:member, [String.t()]}
          | {:partstat,
             :accepted
             | :declined
             | :tentative
             | :needs_action
             | :delegated
             | :completed
             | :in_process
             | x_value()}
          | {:range, :this_and_prior | :this_and_future}
          | {:related, :start | :end}
          | {:reltype, :parent | :child | :sibling | x_value()}
          | {:role, :chair | :req_participant | :non_participant | :opt_participant | x_value()}
          | {:rsvp, boolean()}
          | {:sent_by, String.t()}
          # todo tzid
          | {:value,
             :date
             | :date_time
             | :time
             | :duration
             | :cal_address
             | :boolean
             | :integer
             | :period
             | :float
             | :text
             | :uri
             | :utc_offset
             | x_value()}
          | {x_value(), String.t()}

  @type property() :: {String.t(), [attribute()], String.t() | [String.t()]}
  @type component() :: {:event | :todo | x_value(), [property()]}
  @type t() :: {:calendar, prodid(), version(), [component()]}
end
