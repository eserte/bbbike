// (c) 2013 Slaven Rezic

function ScrollArray(capacity) {
    this.capacity = capacity;
    this.empty();
}
ScrollArray.prototype.push = function(val) {
    this.pos++;
    if (this.pos >= this.capacity) {
	this.pos = 0;
	this.wrapped = true;
    }
    this.container[this.pos] = val;
};
ScrollArray.prototype.get_inx = function(inx) {
    if (!this.wrapped) {
	if (inx <= this.pos) {
	    return inx;
	} else {
	    return null;
	}
    } else {
	if (inx >= this.capacity-this.pos-1) {
	    // left of pos
	    return inx - (this.capacity - this.pos - 1);
	} else {
	    // right of pos
	    return this.pos + 1 + inx;
	}
    }
};
ScrollArray.prototype.get_val = function(inx) {
    var inx = this.get_inx(inx);
    if (inx != null) {
	return this.container[inx];
    } else {
	return null;
    }
};
ScrollArray.prototype.empty = function() {
    this.container = [];
    this.pos = -1;
    this.wrapped = false;
};
ScrollArray.prototype.as_array = function() {
    var res = [];
    for (var inx = 0; inx < this.capacity; inx++) {
	var val = this.get_val(inx);
	if (val == null) break;
	res.push(val);
    }
    return res;
};
