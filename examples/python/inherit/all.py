#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# debugger_entry = /Users/bachi/jayli/gogogo/python/index.py

from dotmap import DotMap as CreateObject
import sys
import re

class A:       pass
class B(A):    pass
class C(A):    pass
class D(B, C): pass
class E:       pass
class F(D, E): pass

def init():
    b = B()
    # print(dir(type(F())))

    o = CreateObject({
        'a':1,
        'b':2,
        'c':{
            'd':3,
            'f':{
                'e':4
            }
        }
    })

    o.c.g = 5
    print(o.__name__)
    print("---------------->>")
    klass_obj = get_full_class_obj_structure(F)
    # TODO printable_list 已经正确的创建，下一步，将它正确的绘制出来
    printable_list = get_printable_list(klass_obj)
    print(printable_list)
    print("---------------->>")

    full_output = object_tree(F())
    print(full_output)

    full_output = trim_tree_list(modify_node(0,full_output))
    show_the_tree(full_output)

def get_full_class_obj_structure(klass):
    root_obj = {}
    try: 
        root_obj[klass.__name__] = create_object_from_class(klass)
        return CreateObject(root_obj)
    except AttributeError:
        print('入参应该是类', sys.exc_info()[0])
    return None

def get_printable_list(obj):
    # jayli
    all_list = []
    for item in dir(obj):
        __import__('pdb').set_trace()
        child_var = obj[item]
        if type(child_var) == type(CreateObject({})):
            child_node = get_printable_list(child_var)
        else:
            child_node = child_var
        parsed_obj = {
            "name":item,
            "child":child_node,
        }
        all_list.append(parsed_obj)
    return all_list 

def create_object_from_class(klass):
    # 如果是根类
    if type(klass) is not type:
        return klass

    if klass.__base__ is object:
        return 'object'

    new_obj = CreateObject()
    for item in klass.__bases__:
        if type(item) is not type:
            new_obj[str(item)] = " "
        else:
            new_obj[item.__name__] = create_object_from_class(item)

    return new_obj

# 清除掉首字符的空白符
def trim_tree_list(full_output):
    '''
    for arr in full_output:
        if re.match(r"^\s*$",arr[0]):
            arr.pop(0)
    '''
    return full_output

# 绘制Tree
def show_the_tree(full_output):
    for item in full_output:
        print("".join(item))
    return full_output

def class_tree(cls, level , full_output):
    line_output = []
    
    index = 1
    if level <= 1:
        line_output = [" ",cls.__name__]
    else:
        while index < level:
            line_output.append(" ")
            index += 1
        line_output.extend(["└", cls.__name__])
    
    full_output.append(line_output)
    # print(" " * level, "└─", cls.__name__)
    for supcls in cls.__bases__:
        class_tree(supcls, level + 1, full_output)

    return full_output

'''
# TODO
def generate_full_output(obj, full_output):
    line_output = []
    
    for item in dir(obj):
        if type(item) is str:
            line_output = []
'''

    


def object_tree(obj):
    # Tree of obj
    return class_tree(obj.__class__, 1, [])

# line_number: 当前游标所在的行索引,0,1,2,3,4...
# full_output: 当前可视结构的全量数组
# return: 返回修正之后的全量数组
def modify_node(line_number, full_output):
    # 当前数组长度, 1,2,3,4...
    current_length = len(full_output[line_number])

    # 如果遍历结束，直接返回全量数组，结束递归
    if line_number == len(full_output) - 1:
        return full_output

    # 找到当前行所属的根节点位置（0,1,2,3...）
    myroot = get_root_number(line_number,full_output)

    # 找到所属根节点后，修改连接线样式
    tdex = myroot + 1
    while tdex < line_number:
        tmp = full_output[tdex]
        if len(tmp) == current_length:
            if len(full_output[tdex + 1]) > len(tmp):
                tmp[current_length - 2] = "├"
            else: pass
        elif len(tmp) > current_length:
            tmp[current_length - 2] = "│"
        else: pass
        tdex += 1

    return modify_node(line_number + 1, full_output)

# 得到当前行所属的根节点位置 return 0,1,2,3...
def get_root_number(line_number, full_output):
    myroot = 0
    current_length = len(full_output[line_number])
    index = line_number - 1
    while index > 0:
        # 寻找根节点
        tmp = full_output[index]
        if len(tmp) == current_length - 1: # 找到根节点
            myroot = index
            break
        index -= 1
    return myroot
    
