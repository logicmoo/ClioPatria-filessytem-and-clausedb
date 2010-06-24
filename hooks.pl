/*  Part of ClioPatria SeRQL and SPARQL server

    Author:        Jan Wielemaker
    E-mail:        J.Wielemaker@cs.vu.nl
    WWW:           http://www.swi-prolog.org
    Copyright (C): 2010, University of Amsterdam,
		   VU University Amsterdam

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

    As a special exception, if you link this library with other files,
    compiled with a Free Software compiler, to produce an executable, this
    library does not by itself cause the resulting executable to be covered
    by the GNU General Public License. This exception does not however
    invalidate any other reasons why the executable file might be covered by
    the GNU General Public License.
*/

:- module(cliopatria, []).

/** <module> ClioPatria hooks

*/

:- multifile
	menu_item/2,
	menu_label/2,
	menu_popup_order/2,

	label_property/1.


		 /*******************************
		 *	     THE MENU		*
		 *******************************/

%%	menu_item(?Item, ?Label)
%
%	This hook adds an item to the ClioPatria menu. Item is a term of
%	the form popup/item, where _popup_ denotes the name of the popup
%	menu and _item_ is a (new) item to   be  added to the popup. The
%	_item_ is the  handler-identifier  of   the  HTTP  handler  that
%	implements the item (see  http_handler/3).   Label  is the label
%	displayed.
%
%	@see menu_label/2 and menu_popup_order/2.

%%	menu_label(+Id, -Label)
%
%	This hook allows for dynamic   or  redefined (i.e. multilingual)
%	labels.  It  is   called   both    for   popup-identifiers   and
%	item-identifiers.

%%	menu_popup_order(+Id, -Location:integer)
%
%	This hook controls the order of the popup-item of ClioPatria's
%	menu.


		 /*******************************
		 *		LABELS		*
		 *******************************/

%%	label_property(?Property)
%
%	True if the value of  Property   can  be  used to (non-uniquely)
%	describe an object to the user.   This  hook provides additional
%	facts to cp_label:label_property/1.