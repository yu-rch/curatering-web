((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,D={aLw:function aLw(){}},B,E
J=c[1]
A=c[0]
C=c[2]
D=a.updateHolder(c[14],D)
B=c[33]
E=c[34]
D.aLw.prototype={
EH(d){return this.azh(d)},
azh(d){var x=0,w=A.l(y.i),v,u,t,s,r,q
var $async$EH=A.m(function(e,f){if(e===1)return A.i(f,w)
for(;;)switch(x){case 0:x=3
return A.d(A.es(A.bx("https://curatering.up.railway.app/api/online-inquiries",0,null),C.a6.co(d,null),null,E.kE).cz(C.fn),$async$EH)
case 3:q=f
if(q.b<200||q.b>=300){u="Failed to submit online inquiry ("+q.b+")"
try{s=q
t=C.a6.bq(A.ch(A.cg(s.e)).b6(s.w),null)
if(y.l.b(t)&&t.h(0,"message")!=null)u=J.u(t.h(0,"message"))}catch(p){}throw A.p(A.lg(u,q.b))}s=q
if(C.e.l(A.ch(A.cg(s.e)).b6(s.w)).length===0){v=C.hT
x=1
break}s=q
t=C.a6.bq(A.ch(A.cg(s.e)).b6(s.w),null)
v=y.l.b(t)?A.ax(t,y.g,y.b):C.hT
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$EH,w)},
a5g(d,e,f){return this.bl5(d,e,f)},
bl5(d,e,f){var x=0,w=A.l(y.i),v
var $async$a5g=A.m(function(g,h){if(g===1)return A.i(h,w)
for(;;)switch(x){case 0:v=$.bM().e1("/api/public/events/theme-design/yolo-sam-infer",A.N(["imageBase64",d,"confidenceThreshold",0.25,"maxDetections",f,"maskFormat",e],y.g,y.b)).cz(B.h5)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a5g,w)},
Mt(d,e,f){return this.aEz(d,e,f)},
aEz(d,e,f){var x=0,w=A.l(y.i),v
var $async$Mt=A.m(function(g,h){if(g===1)return A.i(h,w)
for(;;)switch(x){case 0:v=$.bM().e1("/api/public/events/theme-design/swap-colors",A.N(["imageBase64",e,"masks",f,"edits",d],y.g,y.b)).cz(B.h5)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$Mt,w)},
WH(d,e,f,g,h,i,j,k){return this.ay0(d,e,f,g,h,i,j,k)},
ay0(d,e,f,g,h,i,j,k){var x=0,w=A.l(y.i),v
var $async$WH=A.m(function(l,m){if(l===1)return A.i(m,w)
for(;;)switch(x){case 0:v=$.bM().e1("/api/public/events/theme-design/theme-search",A.N(["eventTitle",e,"eventType",f,"formalityLevel",g,"prompt",j,"baseImageUrl",d,"tags",k,"page",h,"perPage",i],y.g,y.b)).cz(B.h5)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$WH,w)},
a4y(d){return this.biR(d)},
biR(d){var x=0,w=A.l(y.i),v
var $async$a4y=A.m(function(e,f){if(e===1)return A.i(f,w)
for(;;)switch(x){case 0:v=$.bM().e1("/api/public/events/theme-design/extract-objects",A.N(["imagesBase64",d,"confidenceThreshold",0.25,"maxDetections",20],y.g,y.b)).cz(B.h5)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a4y,w)},
a2M(d){return this.bdT(d)},
bdT(d){var x=0,w=A.l(y.i),v
var $async$a2M=A.m(function(e,f){if(e===1)return A.i(f,w)
for(;;)switch(x){case 0:v=$.bM().e1("/api/public/events/theme-design/analyze-base",A.N(["baseImageBase64",d],y.g,y.b)).cz(B.h5)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a2M,w)},
a2X(d,e){return this.bee(d,e)},
bee(d,e){var x=0,w=A.l(y.i),v
var $async$a2X=A.m(function(f,g){if(f===1)return A.i(g,w)
for(;;)switch(x){case 0:v=$.bM().e1("/api/public/events/theme-design/auto-place",A.N(["freeSpaces",d,"objects",e],y.g,y.b)).cz(B.h5)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a2X,w)},
a73(d,e){return this.bq0(d,e)},
bq0(d,e){var x=0,w=A.l(y.i),v
var $async$a73=A.m(function(f,g){if(f===1)return A.i(g,w)
for(;;)switch(x){case 0:v=$.bM().e1("/api/public/events/theme-design/render-composite",A.N(["baseImageBase64",d,"objects",e],y.g,y.b)).cz(B.h5)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a73,w)}}
var z=a.updateTypes([]);(function inheritance(){var x=a.inherit
x(D.aLw,A.a8)})()
var y={i:A.ak("U<e,@>"),l:A.ak("U<@,@>"),g:A.ak("e"),b:A.ak("@")};(function constants(){B.h5=new A.bG(18e7)
B.J5=new A.aj(C.IM,null,null,null,null)
B.z8=new A.aj(C.nU,null,null,null,null)
B.Is=new A.al(58460,"MaterialIcons",!0)
B.C4=new A.X(1/0,48)
B.CM=new A.M(!0,C.cR,null,null,null,null,20,C.a5,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
B.CQ=new A.M(!0,null,null,null,null,null,12,C.az,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
B.a2W=new A.o("Back",null,null,null,null,null,null,null,null,null,null)})();(function lazyInitializers(){var x=a.lazyFinal
x($,"cJl","tm",()=>new D.aLw())})()};
(a=>{a["9GSZKuuh9lUMYXtUTlTW9ptvDhM="]=a.current})($__dart_deferred_initializers__);