[% MACRO t(param) BLOCK -%]
[%
    IF template_type == "TT";
%][% ${"ms$param"} %][%
    ELSE;
%][% "[" _ param _ "]" %][%
    END;
-%]
[% END -%]
